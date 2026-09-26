# jumppad requires a default on every variable -- "required" ones below
# use "" and are enforced at runtime by the scripts' `: "${VAR:?}"` guards.

variable "k8s_cluster" {
  default     = ""
  description = "The k8s_cluster resource to install ArgoCD into and sync onto. Pass `resource.k8s_cluster.<name>`."
}

variable "repo_url" {
  default     = ""
  description = "HTTPS clone URL of the repo ArgoCD syncs from, e.g. \"https://github.com/org/repo.git\", \"https://gitlab.com/org/repo.git\", or a self-hosted Gitea URL."
}

variable "repo_username" {
  default     = ""
  description = <<-EOF
    Username for HTTPS auth against repo_url. Leave empty for a public
    repo -- no credentials are created and ArgoCD syncs anonymously.
    Convention for private repos varies by host: GitHub accepts any
    placeholder (e.g. "x-access-token") alongside a PAT; GitLab expects
    "oauth2"; Gitea typically wants your real username.
  EOF
}

variable "repo_token" {
  default     = ""
  description = "PAT/token paired with repo_username. Leave empty along with repo_username for a public repo."
}

variable "app_namespace" {
  default     = ""
  description = "Kubernetes namespace the app-of-apps deploys into. Not assumed to equal repo_username/org."
}

variable "argocd_project" {
  default     = ""
  description = "ArgoCD AppProject name -- matches repo_url's projects/<name>.yaml."
}

variable "app_path" {
  default     = ""
  description = "Path within the repo the root Application points at, e.g. \"environments/dev/apps\"."
}

variable "argocd_version" {
  default     = "v3.5.1"
  description = "Pinned ArgoCD version. Shared default -- override per caller only if a project genuinely needs to diverge."
}

variable "extra_source_repos" {
  default     = []
  description = <<-EOF
    Additional repos to whitelist in the AppProject's sourceRepos, beyond
    repo_url itself -- e.g. a Helm repo (["https://helm.manticoresearch.com/"]).
    Most callers leave this empty.
  EOF
}

variable "create_registry_secret" {
  default     = "true"
  description = "Set \"false\" to skip creating an image-pull secret entirely (e.g. public images, or one already provisioned another way)."
}

variable "registry_secret_name" {
  default     = "ghcr-pull-secret"
  description = "Name of the created image-pull secret. Must match imagePullSecrets in the repo's manifests."
}

variable "registry_server" {
  default     = "ghcr.io"
  description = "Container registry host for the image-pull secret."
}

variable "registry_username" {
  default     = ""
  description = "Registry username. Required unless create_registry_secret is \"false\"."
}

variable "registry_password" {
  default     = ""
  description = "Registry password/token. Falls back to repo_token if left empty (common when one PAT covers both git and registry access)."
}
