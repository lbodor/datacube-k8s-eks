data "helm_repository" "stable" {
  name       = "stable"
  url        = "https://kubernetes-charts.storage.googleapis.com"
  depends_on = [null_resource.helm_init_client]
}

data "helm_repository" "incubator" {
  name       = "incubator"
  url        = "https://kubernetes-charts-incubator.storage.googleapis.com/"
  depends_on = [null_resource.repo_add_incubator]
}

data "helm_repository" "fluxcd" {
  name       = "fluxcd"
  url        = "https://fluxcd.github.io/flux"
  depends_on = [null_resource.repo_add_fluxcd]
}

data "helm_repository" "eks" {
  name       = "eks"
  url        = "https://aws.github.io/eks-charts"
  depends_on = [null_resource.repo_add_eks]
}

# Initialize and destroy helm / tiller
resource "null_resource" "helm_init_client" {
  provisioner "local-exec" {
    command = "helm init --wait --service-account ${kubernetes_cluster_role_binding.tiller_clusterrolebinding.subject[0].name}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete deployment/tiller-deploy -n kube-system || true"
  }
}

# Helm repo data sources still require to be added through `helm repo add`
resource "null_resource" "repo_add_incubator" {
  provisioner "local-exec" {
    command = "helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/"
  }
  triggers = {
    id = null_resource.helm_init_client.id
  }
}

resource "null_resource" "repo_add_fluxcd" {
  provisioner "local-exec" {
    command = "helm repo add fluxcd https://fluxcd.github.io/flux"
  }
  triggers = {
    id = null_resource.helm_init_client.id
  }
}

resource "null_resource" "repo_add_eks" {
  provisioner "local-exec" {
    command = "helm repo add eks https://aws.github.io/eks-charts"
  }
  triggers = {
    id = null_resource.helm_init_client.id
  }
}