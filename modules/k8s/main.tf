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
