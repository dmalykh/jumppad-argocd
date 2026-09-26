# jumppad-argocd

A [Jumppad](https://jumppad.dev) module that installs ArgoCD into a
Jumppad-managed Kubernetes cluster and bootstraps a GitOps sync from a
remote git repository, using the [app-of-apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
pattern.

Point it at a repo, give it a token, and `jumppad up` gets you a local
cluster running ArgoCD, synced to that repo, with your app's images pulling
from GHCR.

## What it does

- Installs ArgoCD (a vendored, version-pinned install manifest, applied
  server-side)
- Registers your git repo as an ArgoCD repository credential (HTTPS + token)
- Optionally creates an image-pull secret for a private container registry
- Creates an `AppProject` and a root `Application` (app-of-apps)
- Waits for the `Application` to report `Synced` / `Healthy`
- Waits for the resulting Deployments to roll out

Works with GitHub, GitLab, Gitea, or any git host reachable over HTTPS --
it's not GitHub-specific.

## Requirements

- [Jumppad](https://jumppad.dev) >= 0.28
- A `k8s_cluster` resource in your blueprint
- A token with read access to the target repo (and to your image registry,
  if `create_registry_secret` is enabled)

## Usage

```hcl
resource "k8s_cluster" "dev" {
  network {
    id = resource.network.dev.meta.id
  }
}

module "argocd" {
  source = "github.com/dmalykh/jumppad-argocd?ref=v1.0.0"

  variables = {
    k8s_cluster    = resource.k8s_cluster.dev
    repo_url       = "https://github.com/myorg/infra-manifest.git"
    repo_username  = "x-access-token" # GitHub: any placeholder. GitLab: "oauth2". Gitea: your username.
    repo_token     = variable.repo_token
    app_namespace  = "myapp"
    argocd_project = "myapp"
    app_path       = "environments/dev/apps"
  }
}
```

Then:

```
jumppad up
```

Pin `?ref=` to a tagged release. Untagged, it tracks the default branch.

## Variables

| Name | Default | Description |
|---|---|---|
| `k8s_cluster` | *(required)* | The `k8s_cluster` resource to install ArgoCD into. Pass `resource.k8s_cluster.<name>`. |
| `repo_url` | *(required)* | HTTPS clone URL of the repo ArgoCD syncs from. Any git host. |
| `repo_username` | *(required)* | Username for HTTPS auth against `repo_url` (convention varies by host -- see Usage above). |
| `repo_token` | *(required)* | PAT/token paired with `repo_username`. |
| `app_namespace` | *(required)* | Kubernetes namespace the app-of-apps deploys into. |
| `argocd_project` | *(required)* | ArgoCD `AppProject` name. |
| `app_path` | *(required)* | Path within the repo the root `Application` points at. |
| `argocd_version` | `v3.5.1` | Pinned ArgoCD version. See "Bumping the ArgoCD version" below. |
| `extra_source_repos` | `[]` | Additional repos to whitelist in the `AppProject`'s `sourceRepos`, beyond `repo_url` itself (e.g. a Helm repo). |
| `create_registry_secret` | `"true"` | Set `"false"` to skip the image-pull secret entirely. |
| `registry_secret_name` | `"ghcr-pull-secret"` | Name of the created secret. Must match `imagePullSecrets` in your manifests. |
| `registry_server` | `"ghcr.io"` | Container registry host. |
| `registry_username` | *(required if `create_registry_secret`)* | Registry username. |
| `registry_password` | *(falls back to `repo_token`)* | Registry password/token. Leave empty to reuse `repo_token`. |

Jumppad requires every `variable` block to declare a `default`, so the
"required" ones above default to `""` and are enforced at runtime instead
(`: "${VAR:?}"` guards in the module's shell scripts) rather than at parse
time.

## Outputs

None. The one output worth having — ArgoCD's initial admin password — can't
be exposed through a module boundary: it's only known once a script writes
it at runtime, and Jumppad's dependency graph can't resolve a module output
that dynamic. Get it directly instead:

```
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
```

## Bumping the ArgoCD version

`manifests/argocd-install-<version>.yaml` is vendored, not fetched live —
`k8s_config`'s `paths` only accepts local files, and pinning avoids a
runtime dependency on `raw.githubusercontent.com`. To bump the version:

1. `curl -fsS -o manifests/argocd-install-vX.Y.Z.yaml https://raw.githubusercontent.com/argoproj/argo-cd/vX.Y.Z/manifests/install.yaml`
2. Set `argocd_version`'s default (in `variables.hcl`) or pass it as a caller variable.

## Design notes

Most of this module is declarative (`template` + `k8s_config` resources).
Three pieces are shell scripts instead, each for a structural reason rather
than a missed shortcut:

- **ArgoCD's install** runs via `kubectl apply --server-side
  --force-conflicts`. Jumppad's `k8s_config` resource applies through
  Helm's `pkg/kube` client, which hits a `last-applied-configuration
  annotation too long` error on the `applicationsets.argoproj.io` CRD (its
  embedded OpenAPI schema exceeds Kubernetes' 262144-byte annotation cap).
  `k8s_config` has no server-side-apply option to work around this.
- **The registry pull secret** is created via `kubectl create secret
  docker-registry`, which builds the required base64 `auth` field
  correctly. Neither Jumppad's HCL functions nor its `template` resource's
  templating engine expose a base64 helper.
- **Sync-wait and rollout-wait** poll ArgoCD's `Application.status.sync`/
  `.health` fields and discover Deployment names dynamically. `k8s_config`'s
  `health_check` only supports Kubernetes pod label selectors — it has no
  way to watch a custom resource's status field, and this module doesn't
  hardcode the Deployment names it waits on, since those vary by caller.

## License

[MIT](LICENSE)
