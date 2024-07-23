resource "helm_release" "prometheus-stack" {
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  name  = "prometheus-stack"
}