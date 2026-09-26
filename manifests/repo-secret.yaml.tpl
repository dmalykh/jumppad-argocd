apiVersion: v1
kind: Secret
metadata:
  name: infra-manifest-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: {{repo_url}}
  username: {{repo_username}}
  password: {{repo_token}}
