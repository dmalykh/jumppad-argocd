# install_argocd and argocd_bootstrap stay bash -- see README "Design notes".

resource "template" "namespaces" {
  source      = file("manifests/namespaces.yaml.tpl")
  destination = ".generated/namespaces.yaml"

  variables = {
    app_namespace = variable.app_namespace
  }
}

resource "k8s_config" "namespaces" {
  cluster = variable.k8s_cluster
  paths   = [resource.template.namespaces.destination]

  wait_until_ready = false
}

# Verbatim copy (no `variables`) -- just to get an absolute path exec can read.
resource "template" "argocd_install_manifest" {
  source      = file("manifests/argocd-install-${variable.argocd_version}.yaml")
  destination = ".generated/argocd-install-${variable.argocd_version}.yaml"
}

resource "exec" "install_argocd" {
  script = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail
    : "$${ARGOCD_MANIFEST:?}" "$${KUBECONFIG:?}"
    kubectl apply --server-side --force-conflicts -n argocd -f "$ARGOCD_MANIFEST"
    kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
    kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
    kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
  EOT

  environment = {
    KUBECONFIG      = variable.k8s_cluster.kube_config.path
    ARGOCD_MANIFEST = resource.template.argocd_install_manifest.destination
  }

  timeout = "1800s" # cold-cache install can take ~16min

  depends_on = ["resource.k8s_config.namespaces"]
}

resource "template" "repo_secret" {
  source      = file("manifests/repo-secret.yaml.tpl")
  destination = ".generated/repo-secret.yaml"

  variables = {
    repo_url      = variable.repo_url
    repo_username = variable.repo_username
    repo_token    = variable.repo_token
  }
}

resource "k8s_config" "repo_secret" {
  cluster = variable.k8s_cluster
  paths   = [resource.template.repo_secret.destination]

  wait_until_ready = false

  depends_on = ["resource.k8s_config.namespaces"]
}

resource "template" "appproject_application" {
  source      = file("manifests/appproject-application.yaml.tpl")
  destination = ".generated/appproject-application.yaml"

  variables = {
    argocd_project = variable.argocd_project
    repo_url       = variable.repo_url
    app_namespace  = variable.app_namespace
    app_path       = variable.app_path

    # Built as a string, not a list -- a list value here breaks substitution.
    extra_source_repos_yaml = join("\n", formatlist("    - %s", variable.extra_source_repos))
  }
}

resource "k8s_config" "appproject_application" {
  cluster = variable.k8s_cluster
  paths   = [resource.template.appproject_application.destination]

  wait_until_ready = false

  depends_on = [
    "resource.exec.install_argocd",    # needs the CRDs
    "resource.k8s_config.repo_secret", # avoids an initial auth-failure blip
  ]
}

resource "exec" "argocd_bootstrap" {
  script = file("scripts/argocd-bootstrap.sh")

  environment = {
    KUBECONFIG             = variable.k8s_cluster.kube_config.path
    APP_NAMESPACE          = variable.app_namespace
    ARGOCD_PROJECT         = variable.argocd_project
    REPO_TOKEN             = variable.repo_token
    CREATE_REGISTRY_SECRET = variable.create_registry_secret
    REGISTRY_SECRET_NAME   = variable.registry_secret_name
    REGISTRY_SERVER        = variable.registry_server
    REGISTRY_USERNAME      = variable.registry_username
    REGISTRY_PASSWORD      = variable.registry_password
  }

  timeout = "1800s"

  depends_on = [
    "resource.k8s_config.namespaces",
    "resource.k8s_config.appproject_application",
  ]
}
