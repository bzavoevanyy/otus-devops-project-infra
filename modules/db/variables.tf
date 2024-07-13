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

variable "pg_bases" {
  description = "Список БД и юзеров-владельцев"
  type = list(object({
    db_name            = string
    db_owner_user_name = string
  }))
}

variable "pg_users" {
  description = "Список юзеров: логин и пароль"
  type = list(object({
    db_user_name  = string
    db_user_pass  = string
    db_conn_limit = string
  }))
}

variable "db_admin_pass" {
  description = "db admin password"
}

variable "assign_public_ip" {
  description = "Разрешить публичный доступ к кластеру postgres"
  default = false
}

variable "folder_name" {
  description = "Имя каталога в облаке"
}
