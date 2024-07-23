terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

locals {
  ci-cd-sa = var.ci-cd-sa != "" ? var.ci-cd-sa : "${data.yandex_resourcemanager_folder.target_folder.name}-ci-cd-sa"
}

data "yandex_resourcemanager_folder" "target_folder" {
  name = var.folder_name
}

resource "yandex_vpc_subnet" "k8s-subnet" {
  description    = "Сеть для развертывания k8s кластера"
  name           = var.vpc_subnet_name
  zone           = var.zone
  network_id     = var.vpc_network_id
  v4_cidr_blocks = var.vpc_v4_cidr_blocks
  folder_id      = data.yandex_resourcemanager_folder.target_folder.id
}

resource "yandex_vpc_security_group" "k8s-main-sg" {
  name        = "k8s-main-sg"
  description = "Правила группы обеспечивают базовую работоспособность кластера. Примените ее к кластеру и группам узлов."
  network_id  = var.vpc_network_id
  ingress {
    protocol          = "TCP"
    description       = "Правило разрешает проверки доступности с диапазона адресов балансировщика нагрузки. Нужно для работы отказоустойчивого кластера и сервисов балансировщика."
    predefined_target = "loadbalancer_healthchecks"
    port              = 10256
  }
  ingress {
    protocol          = "ANY"
    description       = "Правило разрешает взаимодействие мастер-узел и узел-узел внутри группы безопасности."
    predefined_target = "self_security_group"
    from_port         = 0
    to_port           = 65535
  }
  ingress {
    protocol       = "ANY"
    description    = "Правило разрешает взаимодействие под-под и сервис-сервис. Укажите подсети вашего кластера и сервисов."
    v4_cidr_blocks = [var.cluster_ipv4_range, var.service_ipv4_range]
    from_port      = 0
    to_port        = 65535
  }
  ingress {
    protocol       = "ICMP"
    description    = "Правило разрешает отладочные ICMP-пакеты из внутренних подсетей."
    v4_cidr_blocks = ["172.16.0.0/12", "10.0.0.0/8", "192.168.0.0/16"]
  }
  egress {
    protocol       = "ANY"
    description    = "Правило разрешает весь исходящий трафик. Узлы могут связаться с Yandex Container Registry, Object Storage, Docker Hub и т. д."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

resource "yandex_vpc_security_group" "k8s-public-services" {
  name        = "k8s-public-services"
  description = "Правила группы разрешают подключение к сервисам из интернета. Примените правила только для групп узлов."
  network_id  = var.vpc_network_id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает входящий трафик из интернета на диапазон портов NodePort. Добавьте или измените порты на нужные вам."
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }
}

resource "yandex_vpc_security_group" "k8s-master-whitelist" {
  name        = "k8s-master-whitelist"
  description = "Правила группы разрешают доступ к API Kubernetes из интернета. Примените правила только к кластеру."
  network_id  = var.vpc_network_id

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 6443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }

  ingress {
    protocol       = "TCP"
    description    = "Правило разрешает подключение к API Kubernetes через порт 443 из указанной сети."
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
}

# Соль для sa, что бы не совпадало с другими sa
resource "random_id" "k8s_sa_salt" {
  byte_length = 4
}

resource "yandex_iam_service_account" "k8s-sa" {
  name        = "${var.cluster_name}-${random_id.k8s_sa_salt.hex}"
  description = "sa для управления k8s"
  folder_id   = data.yandex_resourcemanager_folder.target_folder.id
}

# Права для sa
resource "yandex_resourcemanager_folder_iam_member" "k8s-sa-vpc-user" {
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  role      = "vpc.user"
}
resource "yandex_resourcemanager_folder_iam_member" "k8s-sa-vpc-private-admin" {
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  role      = "vpc.privateAdmin"
}
resource "yandex_resourcemanager_folder_iam_member" "k8s-sa-vpc-public-admin" {
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  role      = "vpc.publicAdmin"
}
resource "yandex_resourcemanager_folder_iam_member" "k8s-sa-cr-puller" {
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  role      = "container-registry.images.puller"
}

resource "yandex_resourcemanager_folder_iam_member" "kubernetes_sa_agent" {
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  role      = "k8s.tunnelClusters.agent"
}

resource "yandex_resourcemanager_folder_iam_member" "kubernetes_sa_lb_admin" {
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
  member    = "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  role      = "load-balancer.admin"
}

# sa для генерации kubeconfig
resource "yandex_iam_service_account" "ci-cd-sa" {
  name        = local.ci-cd-sa
  folder_id   = data.yandex_resourcemanager_folder.target_folder.id
  description = "Сервисный аккаунт для управления k8s в ci/cd"
}
resource "yandex_resourcemanager_folder_iam_member" "k8s-viewer" {
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
  member    = "serviceAccount:${yandex_iam_service_account.ci-cd-sa.id}"
  role      = "k8s.viewer"
}

resource "yandex_kubernetes_cluster" "k8s-cluster" {
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s-sa-cr-puller,
    yandex_resourcemanager_folder_iam_member.k8s-sa-vpc-private-admin,
    yandex_resourcemanager_folder_iam_member.k8s-sa-vpc-public-admin,
    yandex_resourcemanager_folder_iam_member.k8s-sa-vpc-user,
    yandex_resourcemanager_folder_iam_member.kubernetes_sa_agent
  ]
  network_id              = var.vpc_network_id
  folder_id               = data.yandex_resourcemanager_folder.target_folder.id
  node_service_account_id = yandex_iam_service_account.k8s-sa.id
  service_account_id      = yandex_iam_service_account.k8s-sa.id
  release_channel         = var.release_channel

  cluster_ipv4_range = var.cluster_ipv4_range
  service_ipv4_range = var.service_ipv4_range

  master {
    public_ip = true
    version   = var.k8s_version
    zonal {
      zone      = yandex_vpc_subnet.k8s-subnet.zone
      subnet_id = yandex_vpc_subnet.k8s-subnet.id
    }
    maintenance_policy {
      auto_upgrade = false
    }
    security_group_ids = [
      yandex_vpc_security_group.k8s-main-sg.id,
      yandex_vpc_security_group.k8s-master-whitelist.id
    ]
  }
}

resource "yandex_kubernetes_node_group" "k8s-workers" {
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  name        = "k8s-workers-${var.cluster_name}"
  description = "Ноды для k8s кластера"
  version     = var.k8s_version

  scale_policy {
    dynamic "fixed_scale" {
      for_each = var.fixed_scale_policy[*]
      content {
        size = fixed_scale.value.size
      }
    }
    dynamic "auto_scale" {
      for_each = var.auto_scale_policy[*]
      content {
        min     = auto_scale.value.min
        max     = auto_scale.value.max
        initial = auto_scale.value.initial
      }
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.k8s-subnet.zone
    }
  }

  instance_template {
    container_runtime {
      type = "containerd"
    }
    network_interface {
      subnet_ids = [yandex_vpc_subnet.k8s-subnet.id]
      nat = true
    }
    boot_disk {
      type = var.worker_disk_type
      size = var.worker_disk_size_gb
    }
    metadata = {
      ssh-keys = join("\n", var.worker_ssh_keys)
    }
    platform_id = var.worker_platform_id
    scheduling_policy {
      preemptible = var.worker_preemptible
    }
    resources {
      cores         = var.worker_cpu
      memory        = var.worker_ram_gb
      core_fraction = var.worker_cpu_fraction
    }
  }
}
