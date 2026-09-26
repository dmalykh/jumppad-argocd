#!/usr/bin/env bash
set -euo pipefail

# ghcr-pull-secret + sync-wait + rollout-wait -- see README "Design notes".
#
# Required env: GITHUB_TOKEN, APP_NAMESPACE, ARGOCD_PROJECT, KUBECONFIG

: "${GITHUB_TOKEN:?}" "${APP_NAMESPACE:?}" "${ARGOCD_PROJECT:?}" "${KUBECONFIG:?}"

log() { printf '%s\n' "$*"; }

# GHCR needs the real username, unlike git-over-HTTPS's x-access-token placeholder.
github_username() {
  curl -fsS -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user \
    | grep -o '"login": *"[^"]*"' | head -1 | sed -E 's/.*"login": *"([^"]*)".*/\1/'
}

# Builds the base64 auth field correctly; no base64 function in HCL/templates.
create_ghcr_secret() {
  local gh_user
  gh_user="$(github_username)"
  [[ -n "$gh_user" ]] || { log "Could not derive a GitHub username from GITHUB_TOKEN."; return 1; }

  kubectl -n "$APP_NAMESPACE" create secret docker-registry ghcr-pull-secret \
    --docker-server=ghcr.io \
    --docker-username="$gh_user" \
    --docker-password="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
}

# No webhook reaches a local cluster, so force an immediate re-check.
hard_refresh_app() {
  kubectl -n argocd annotate application "$1" argocd.argoproj.io/refresh=hard --overwrite >/dev/null
}

# Waits for every Application in $ARGOCD_PROJECT to be Synced/Healthy.
wait_for_sync() {
  local elapsed=0 apps app sync health all_ready refreshed_apps=" "
  while true; do
    apps=()
    while IFS= read -r app; do
      [[ -n "$app" ]] && apps+=("$app")
    done < <(kubectl -n argocd get applications \
      -o jsonpath="{range .items[?(@.spec.project==\"${ARGOCD_PROJECT}\")]}{.metadata.name}{\"\n\"}{end}" 2>/dev/null)

    all_ready=1
    if (( ${#apps[@]} == 0 )); then
      all_ready=0
    else
      for app in "${apps[@]}"; do
        if [[ "$refreshed_apps" != *" $app "* ]]; then
          hard_refresh_app "$app"
          refreshed_apps+="$app "
          all_ready=0
          continue
        fi

        sync="$(kubectl -n argocd get application "$app" -o jsonpath='{.status.sync.status}' 2>/dev/null)"
        health="$(kubectl -n argocd get application "$app" -o jsonpath='{.status.health.status}' 2>/dev/null)"
        if [[ "$sync" != "Synced" || "$health" != "Healthy" ]]; then
          all_ready=0
        fi
      done
    fi

    if (( all_ready == 1 )); then
      return 0
    fi

    sleep 5
    elapsed=$((elapsed + 5))
    if (( elapsed >= 600 )); then
      log "Timed out waiting for ArgoCD apps to become Synced/Healthy: ${apps[*]:-<none found yet>}"
      return 1
    fi
  done
}

# Deployment names aren't hardcoded; they vary per caller.
wait_for_rollout() {
  local deploy
  while IFS= read -r deploy; do
    [[ -n "$deploy" ]] || continue
    kubectl -n "$APP_NAMESPACE" rollout status "$deploy" --timeout=120s
  done < <(kubectl -n "$APP_NAMESPACE" get deploy -o name 2>/dev/null)
}

log "Configuring GHCR pull credentials…"
create_ghcr_secret
log "Waiting for the app to sync…"
wait_for_sync
log "Waiting for workloads to roll out…"
wait_for_rollout
log "Done."

# Secret is gone once the password's been changed -- that's fine, not an error.
if [[ -n "${EXEC_OUTPUT:-}" ]]; then
  argocd_password="$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || true)"
  if [[ -n "$argocd_password" ]]; then
    echo "ARGOCD_PASSWORD=${argocd_password}" > "$EXEC_OUTPUT"
  fi
fi
