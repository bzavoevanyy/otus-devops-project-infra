terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.14.0"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket = "otus-project"
    region = "ru-central1"
    key    = "terraform/terraform.tfstate"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # Необходимая опция Terraform для версии 1.6.1 и старше.
    skip_s3_checksum            = true # Необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.

  }
}

data "yandex_client_config" "client" {}

provider "helm" {
  kubernetes {
    host = module.k8s.k8s-cluster.master.0.external_v4_endpoint
    cluster_ca_certificate = module.k8s.k8s-cluster.master.0.cluster_ca_certificate
    token = data.yandex_client_config.client.iam_token
  }
}

provider "kubernetes" {
  host = module.k8s.k8s-cluster.master.0.external_v4_endpoint
  cluster_ca_certificate = module.k8s.k8s-cluster.master.0.cluster_ca_certificate
  token = data.yandex_client_config.client.iam_token
}