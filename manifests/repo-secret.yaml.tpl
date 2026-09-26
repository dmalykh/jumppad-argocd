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
  url: https://github.com/{{github_org}}/{{infra_repo}}.git
  username: x-access-token
  password: {{github_token}}
