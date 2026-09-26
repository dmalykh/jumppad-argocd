apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: {{argocd_project}}
  namespace: argocd
spec:
  description: {{argocd_project}} platform stack
  sourceRepos:
    - https://github.com/{{github_org}}/{{infra_repo}}.git
{{extra_source_repos_yaml}}
  destinations:
    - namespace: {{app_namespace}}
      server: https://kubernetes.default.svc
    - namespace: argocd
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ""
      kind: Namespace
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
    repoURL: https://github.com/{{github_org}}/{{infra_repo}}.git
    targetRevision: HEAD
    path: {{app_path}}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
