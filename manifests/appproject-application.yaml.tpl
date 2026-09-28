apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: {{argocd_project}}
  namespace: argocd
spec:
  description: {{argocd_project}} platform stack
  sourceRepos:
    - {{repo_url}}
{{extra_source_repos_yaml}}
  destinations:
    - namespace: {{app_namespace}}
      server: https://kubernetes.default.svc
    - namespace: argocd
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
{{extra_cluster_resources_yaml}}
  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: {{argocd_project}}-dev
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: {{argocd_project}}
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  source:
    repoURL: {{repo_url}}
    targetRevision: {{target_revision}}
    path: {{app_path}}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
