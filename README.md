# jumppad-argocd

A [Jumppad](https://jumppad.dev) module that installs ArgoCD into a
Jumppad-managed Kubernetes cluster and bootstraps a GitOps sync from a
remote git repository, using the [app-of-apps](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
pattern.

Point it at a repo and `jumppad up` gets you a local cluster running
ArgoCD, synced to that repo. Both credentials are optional: skip
`repo_token` for a public repo, skip `create_registry_secret` for public
images.

## What it does

- Installs ArgoCD (a vendored, version-pinned install manifest, applied
  server-side)
- Registers your git repo as an ArgoCD repository credential (HTTPS),
  with credentials only if you supply `repo_token` -- public repos sync
  with none
- Optionally creates an image-pull secret for a private container
  registry, off by default
- Creates an `AppProject` and a root `Application` (app-of-apps)
- Waits for the `Application` to report `Synced` / `Healthy`
- Waits for the resulting Deployments to roll out

Works with GitHub, GitLab, Gitea, or any git host reachable over HTTPS --
it's not GitHub-specific.

## Requirements

- [Jumppad](https://jumppad.dev) >= 0.28
- A `k8s_cluster` resource in your blueprint
- For a private repo: a token with read access to it
- For private images: a token with read access to your registry (can be
  the same token, if it's scoped for both)

## Usage

All examples assume:

```hcl
resource "k8s_cluster" "dev" {
  network {
    id = resource.network.dev.meta.id
  }
}
```

Pin `?ref=` to a tagged release. Untagged, it tracks the default branch.

### GitHub, private repo + GHCR images (PAT for both)

`repo_username` already defaults to `"x-access-token"`, GitHub's own
placeholder, so it's omitted below. One fine-grained PAT (Contents:
Read-only on the repo, Packages: Read-only for GHCR) covers both the repo
credential and the image-pull secret -- `registry_password` falls back to
`repo_token` when left unset.

```hcl
module "argocd" {
  source = "github.com/dmalykh/jumppad-argocd?ref=v1.0.0"

  variables = {
    k8s_cluster            = resource.k8s_cluster.dev
    repo_url               = "https://github.com/myorg/infra-manifest.git"
    repo_token             = variable.repo_token
    create_registry_secret = "true"
    registry_username      = "my-github-username" # GHCR wants the real account, not a placeholder
    app_namespace          = "myapp"
    argocd_project         = "myapp"
    app_path               = "environments/dev/apps"
  }
}
```

### GitHub, public repo, no PAT

Leave `repo_token` unset (default `""`) and no repository credential is
created -- ArgoCD syncs anonymously. `create_registry_secret` is already
`"false"` by default, so this is the minimal call.

```hcl
module "argocd" {
  source = "github.com/dmalykh/jumppad-argocd?ref=v1.0.0"

  variables = {
    k8s_cluster    = resource.k8s_cluster.dev
    repo_url       = "https://github.com/myorg/public-manifests.git"
    app_namespace  = "myapp"
    argocd_project = "myapp"
    app_path       = "environments/dev/apps"
  }
}
```

### Another provider (e.g. GitLab), separate registry credentials

`repo_username` conventions vary by host (GitLab: `"oauth2"`; Gitea:
typically your real username). `registry_*` is independent of `repo_*`,
so a token scoped only to the repo still works even against a different
registry.

```hcl
module "argocd" {
  source = "github.com/dmalykh/jumppad-argocd?ref=v1.0.0"

  variables = {
    k8s_cluster            = resource.k8s_cluster.dev
    repo_url               = "https://gitlab.com/myorg/infra-manifest.git"
    repo_username          = "oauth2"
    repo_token             = variable.gitlab_token
    create_registry_secret = "true"
    registry_server        = "registry.gitlab.com"
    registry_username      = "myorg"
    registry_password      = variable.registry_token
    app_namespace          = "myapp"
    argocd_project         = "myapp"
    app_path               = "environments/dev/apps"
  }
}
```

Then:

```
jumppad up
```

## Variables

| Name | Default | What it's for | Required? |
|---|---|---|---|
| `k8s_cluster` | *(none)* | The cluster to install ArgoCD into. Pass `resource.k8s_cluster.<name>` from your own blueprint. | Always |
| `repo_url` | *(none)* | HTTPS clone URL of the repo ArgoCD syncs from -- copy it from your host's "Clone with HTTPS" button. Any git host. | Always |
| `repo_username` | `"x-access-token"` | Username for HTTPS git auth. Default works for GitHub/GitLab as-is; override for Gitea or a host that validates it. No effect if `repo_token` is empty. | No |
| `repo_token` | *(none)* | PAT with read access to `repo_url`. Get it from GitHub (Settings > Developer settings > Fine-grained tokens), GitLab (Settings > Access Tokens), or Gitea (Settings > Applications). Leave empty for a public repo -- no credential secret is created. | No -- required only for private repos |
| `app_namespace` | *(none)* | Kubernetes namespace your app deploys into (created automatically). Not ArgoCD's own namespace, which is always `argocd`. | Always |
| `argocd_project` | *(none)* | Name for the ArgoCD `AppProject` this module creates -- e.g. your app or org name. | Always |
| `app_path` | *(none)* | Path inside `repo_url` the root `Application` syncs, e.g. `"environments/dev/apps"`. | Always |
| `argocd_version` | `"v3.5.1"` | ArgoCD release to install -- must match a vendored manifest. See "Bumping the ArgoCD version" below. | No |
| `extra_source_repos` | `[]` | Extra repo URLs to whitelist in the `AppProject`'s `sourceRepos`, beyond `repo_url` (e.g. a Helm chart repo). | No |
| `create_registry_secret` | `"false"` | Set `"true"` to create an image-pull secret for a private container registry. | No |
| `registry_secret_name` | `"ghcr-pull-secret"` | Name of the created secret. Must exactly match `imagePullSecrets` in your Deployment manifests. | No |
| `registry_server` | `"ghcr.io"` | Registry hostname images are pulled from. | No |
| `registry_username` | *(none)* | Registry username. Unlike `repo_username`, most registries validate this against the real account. | Only if `create_registry_secret = "true"` |
| `registry_password` | *(none)* | Registry password/token. Leave empty to reuse `repo_token`, when one PAT covers both repo and registry read access. | No |

`k8s_cluster`, `repo_url`, `app_namespace`, `argocd_project`, and
`app_path` have no real default -- Jumppad requires every `variable`
block to declare one, so they default to `""`. `app_namespace` and
`argocd_project` are checked at runtime (`: "${VAR:?}"` guards in
`scripts/argocd-bootstrap.sh`) and fail with a clear error if left
unset. `k8s_cluster`, `repo_url`, and `app_path` aren't guarded the same
way -- leaving one unset produces a broken cluster or malformed
manifest instead of an explicit error, so treat all five as required in
practice.

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
