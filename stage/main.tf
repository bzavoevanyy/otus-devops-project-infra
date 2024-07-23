resource "yandex_vpc_network" "otus-project" {
  name = "otus-project"
}

module "db" {
  source             = "../modules/db"
  vpc_network_id     = yandex_vpc_network.otus-project.id
  vpc_subnet_name    = "pg_subnet"
  vpc_v4_cidr_blocks = var.pg_vpc_v4_cidr_blocks
  zone               = var.zone
  db_admin_pass      = var.db_admin_pass
  pg_bases           = var.pg_bases
  pg_users           = var.pg_users
  assign_public_ip   = true
  folder_name        = var.folder_name
}

module "k8s" {
  source              = "../modules/k8s"
  cluster_ipv4_range  = var.cluster_ipv4_range
  cluster_name        = "k8s-prod"
  folder_name         = var.folder_name
  service_ipv4_range  = var.service_ipv4_range
  vpc_network_id      = yandex_vpc_network.otus-project.id
  vpc_subnet_name     = "k8s-subnet"
  vpc_v4_cidr_blocks  = var.k8s_vpc_v4_cidr_blocks
  zone                = var.zone
  k8s_version         = "1.29"
  worker_cpu          = 2
  worker_preemptible  = true
  worker_cpu_fraction = 20
  worker_platform_id  = "standard-v1"
  worker_disk_size_gb = 30
  auto_scale_policy = {
    max     = 3
    min     = 1
    initial = 1
  }
}

resource "helm_release" "ingress-nginx" {
  chart = "ingress-nginx"
  name  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  create_namespace = true
  namespace = "ingress-nginx"
}

# Namespace для prometheus stack
resource "kubernetes_namespace_v1" "monitoring-ns" {
  metadata {
    name = "monitoring"
  }
}

# Создаем secret basic auth для ingress prometheus
resource "kubernetes_secret_v1" "prometheus-basic-auth" {
  metadata {
    name = "basic-auth"
    namespace = kubernetes_namespace_v1.monitoring-ns.metadata[0].name
  }
  data = {
    auth = "admin:${var.prometheus_admin_pass}"
  }
}

resource "helm_release" "prometheus-stack" {
  depends_on = [
    kubernetes_namespace_v1.monitoring-ns,
    kubernetes_secret_v1.prometheus-basic-auth
  ]
  repository = "https://prometheus-community.github.io/helm-charts"
  chart = "kube-prometheus-stack"
  name  = "prometheus-stack"
  values = [file("${path.module}/files/monitoring-stage.yaml")]
  namespace = "monitoring"

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_pass
  }
}