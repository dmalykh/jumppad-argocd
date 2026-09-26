# jumppad requires a default on every variable -- "required" ones below
# use "" and are enforced at runtime by the scripts' `: "${VAR:?}"` guards.

variable "k8s_cluster" {
  default     = ""
  description = "The k8s_cluster resource to install ArgoCD into and sync onto. Pass `resource.k8s_cluster.<name>`."
}

variable "github_token" {
  default     = ""
  description = <<-EOF
    Fine-grained GitHub PAT (Contents: Read-only on infra_repo, Packages:
    Read-only). No real value defaults here -- every caller supplies its
    own, from its own *.vars file or --var.
  EOF
}

variable "github_org" {
  default     = ""
  description = "GitHub org/user that owns infra_repo and ghcr.io images, e.g. \"trustattic\" or \"arasmog\"."
}

variable "infra_repo" {
  default     = ""
  description = "Repo ArgoCD syncs from, under github_org. Usually \"infra-manifest\"."
}

variable "app_namespace" {
  default     = ""
  description = "Kubernetes namespace the app-of-apps deploys into. Not assumed to equal github_org -- arasmog's is \"hookahgo\", not \"arasmog\"."
}

variable "argocd_project" {
  default     = ""
  description = "ArgoCD AppProject name -- matches infra_repo's projects/<name>.yaml."
}

variable "app_path" {
  default     = ""
  description = "Path within infra_repo the root Application points at, e.g. \"environments/dev/apps\"."
}

variable "argocd_version" {
  default     = "v3.5.1"
  description = "Pinned ArgoCD version. Shared default -- override per caller only if a project genuinely needs to diverge."
}

variable "extra_source_repos" {
  default     = []
  description = <<-EOF
    Additional repos to whitelist in the AppProject's sourceRepos, beyond
    infra_repo itself -- e.g. arasmog's Manticore Helm repo
    (["https://helm.manticoresearch.com/"]). Most callers leave this empty.
  EOF
}
