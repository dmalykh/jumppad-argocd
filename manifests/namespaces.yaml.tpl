apiVersion: v1
kind: Namespace
metadata:
  name: argocd
---
apiVersion: v1
kind: Namespace
metadata:
  name: {{app_namespace}}
