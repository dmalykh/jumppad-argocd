# jumppad requires a default on every variable -- "required" ones below
# use "" and are enforced at runtime by the scripts' `: "${VAR:?}"` guards.

variable "k8s_cluster" {
  default     = ""
  description = <<-EOF
    The cluster ArgoCD installs into. Required -- this module never
    creates its own cluster. Pass the k8s_cluster resource from your own
    blueprint: `resource.k8s_cluster.<name>`.
  EOF
}

variable "repo_url" {
  default     = ""
  description = <<-EOF
    Required. HTTPS clone URL of the repo ArgoCD syncs from (your
    GitOps/manifests repo) -- copy it straight from your host's "Clone
    with HTTPS" button, e.g. "https://github.com/org/repo.git",
    "https://gitlab.com/org/repo.git", or a self-hosted Gitea URL.
  EOF
}

variable "repo_username" {
  default     = "x-access-token"
  description = <<-EOF
    Username paired with repo_token for HTTPS git auth. The default
    works as-is for GitHub and GitLab, which both accept a placeholder
    alongside a real token. Override to your actual account username
    for Gitea or any host that validates it. Has no effect if repo_token
    is empty (public repo -- no credential is created at all).
  EOF
}

variable "repo_token" {
  default     = ""
  description = <<-EOF
    Personal access token (PAT) with read access to repo_url. Leave
    empty for a public repo: no credential secret is created and ArgoCD
    syncs anonymously. Where to get one: GitHub -> Settings > Developer
    settings > Fine-grained tokens (Contents: Read-only, scoped to this
    repo); GitLab -> Settings > Access Tokens (read_repository scope);
    Gitea -> Settings > Applications. Never commit a real value here --
    pass it via `jumppad up --var repo_token=...` or a *.vars file.
  EOF
}

variable "app_namespace" {
  default     = ""
  description = <<-EOF
    Required. Kubernetes namespace your app deploys into -- created
    automatically by this module. Not the same as ArgoCD's own
    namespace, which is always "argocd".
  EOF
}

variable "argocd_project" {
  default     = ""
  description = <<-EOF
    Required. Name for the ArgoCD AppProject this module creates --
    pick anything descriptive, e.g. your app or org name. If repo_url
    keeps per-project config (like projects/<name>.yaml), this must
    match that name.
  EOF
}

variable "app_path" {
  default     = ""
  description = <<-EOF
    Required. Path inside repo_url that the root Application points its
    sync at, e.g. "environments/dev/apps" -- everything under this
    directory in the repo gets applied to app_namespace.
  EOF
}

variable "argocd_version" {
  default     = "v3.5.1"
  description = <<-EOF
    ArgoCD release to install. Must match a vendored
    manifests/argocd-install-<version>.yaml in this module -- see
    "Bumping the ArgoCD version" in README before changing.
  EOF
}

variable "extra_source_repos" {
  default     = []
  description = <<-EOF
    Extra repo URLs to whitelist in the AppProject's sourceRepos,
    beyond repo_url itself -- e.g. a Helm chart repo one of your
    Applications pulls from (["https://helm.manticoresearch.com/"]).
    Most callers leave this empty; it doesn't get any credentials of
    its own.
  EOF
}

variable "create_registry_secret" {
  default     = "false"
  description = <<-EOF
    Set "true" to create an image-pull secret for a private container
    registry. Off by default -- turn it on only if your app's images
    aren't public. When "true", registry_username is also required.
  EOF
}

variable "registry_secret_name" {
  default     = "ghcr-pull-secret"
  description = <<-EOF
    Name of the created image-pull secret. Must exactly match the
    imagePullSecrets name referenced in your Deployment manifests, or
    pods will sit in ImagePullBackOff unable to find it.
  EOF
}

variable "registry_server" {
  default     = "ghcr.io"
  description = "Registry hostname your images are pulled from, e.g. \"ghcr.io\", \"registry.gitlab.com\", or a private registry's host."
}

variable "registry_username" {
  default     = ""
  description = <<-EOF
    Registry username. Required when create_registry_secret is "true".
    Unlike repo_username, most registries (ghcr.io included) validate
    this against the real account that owns the token -- a placeholder
    won't authenticate here.
  EOF
}

variable "registry_password" {
  default     = ""
  description = <<-EOF
    Registry password/token. Leave empty to reuse repo_token -- works
    when one PAT is scoped for both repo read and package/registry read
    access (e.g. a GitHub PAT with Contents:Read-only + Packages:Read-only).
  EOF
}

variable "target_revision" {
  default     = "HEAD"
  description = <<-EOF
    Git revision the root Application syncs -- "HEAD" for the repo's
    default branch, or a branch name, tag or commit SHA. Point it at a
    branch to try an unmerged manifests change against a local cluster
    before landing it.
  EOF
}
