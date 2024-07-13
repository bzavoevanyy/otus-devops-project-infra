variable "vpc_network_id" {
  description = "VPC network id"
}

variable "vpc_subnet_name" {
  description = "VPC subnet name"
}

variable "vpc_v4_cidr_blocks" {
  description = "cidr block"
}

variable "zone" {
  description = "yandex zone"
}

variable "cluster_name" {
  description = "Имя кластера"
}

variable "folder_name" {
  description = "Имя каталога в облаке"
}

variable "ci-cd-sa" {
  description = "Сервисный аккаунт для управления k8s в ci/cd"
  default     = ""
}

variable "release_channel" {
  default = "RAPID"
}

variable "cluster_ipv4_range" {
  type = string
  description = "Не должны пересекаться с существующими подсетями"
}

variable "service_ipv4_range" {
  type = string
  description = "Не должны пересекаться с существующими подсетями"
}

variable "k8s_version" {
  default     = "1.29"
  description = "Версия k8s"
}

variable "fixed_scale_policy" {
  type = object({
    size = number
  })
  default = null
}

variable "auto_scale_policy" {
  type = object({
    min     = number
    max     = number
    initial = number
  })
  default = null
}

variable "worker_disk_type" {
  type = string
  description = "Тип диска worker node"
  default = "network-ssd"
}
variable "worker_disk_size_gb" {
  type = number
  description = "Размер диска worker node"
  default = 30
}
variable "worker_ssh_keys" {
  default = [""]
  type = list(string)
  description = "public key for workers"
}
variable "worker_platform_id" {
  type = string
  default = "standard-v2"
}
variable "worker_preemptible" {
  type = bool
  default = false
}
variable "worker_cpu" {
  type = number
  default = 2
}
variable "worker_ram_gb" {
  type = number
  default = 4
  description = "Кол оперативной памяти в Гб"
}
variable "worker_cpu_fraction" {
  type = number
  default = 50
  validation {
    condition = contains([5, 20, 50, 100], var.worker_cpu_fraction)
    error_message = "cpu fraction must be one of 5, 20, 50, 100"
  }
}
