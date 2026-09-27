# CLAUDE.md

Guidance for working on this repo. See README.md for what the module does
and its variable interface.

## Conventions

- Declarative first: `template` + `k8s_config` over `exec`/bash. New bash
  needs a reason as strong as the 3 in README's "Design notes".
- Comments: one-liners or none. Explanations go in README, not comment
  blocks. `description` attributes aren't comments -- keep them.
- Host-agnostic: no GitHub-specific assumptions. `repo_url`/`repo_username`/
  `repo_token` work with any HTTPS git host; registry vars
  (`registry_server`, `registry_secret_name`, ...) are generic too, and
  `create_registry_secret` defaults to `"false"`.
- Every variable needs a `default` (jumppad requirement) -- `""` means "no
  real default", not "optional". Only `app_namespace`/`argocd_project` are
  actually enforced at runtime (`: "${VAR:?}"` in `argocd-bootstrap.sh`);
  others fail less clearly if left unset.

## Verifying a change

    jumppad validate   # from a caller blueprint, e.g. ../../jumppad
    jumppad up         # full end-to-end, ~15-20min cold cache

No test suite -- this is HCL + bash, validated by running it. Check
`~/.jumppad/logs/` on failure.

## Known jumppad limitations shaping this design

- `k8s_config` applies via Helm's `pkg/kube` client, not server-side apply
  -- fails on CRDs whose schema exceeds the 262144-byte annotation cap
  (ArgoCD's `applicationsets.argoproj.io`). Hence ArgoCD installs via
  `exec`, not `k8s_config`.
- `template`'s `variables` map silently no-ops (copies `source` verbatim)
  if any value is non-string mixed into an otherwise-string map. Pre-join
  lists into a string instead of passing them through `variables`.
- `exec.script = file(...)` stages content under `~/.jumppad/tmp/`,
  detached from this directory -- `BASH_SOURCE`-relative paths break. Use
  a `template` resource's `.destination` for absolute paths instead.
