variable "cloud_id" {
  description = "Cloud"
  default = "b1g5g9urts8pjgi0vrei"
}
variable "folder_name" {
  description = "Имя каталога в облаке"
  default = "cloud-otus"
}
variable "zone" {
  description = "Zone"
  # Значение по умолчанию
  default = "ru-central1-a"
}
variable "pg_vpc_v4_cidr_blocks" {
  type = list(string)
  description = "postgres subnet cidr"
  default = ["192.168.10.80/28"]
}
variable "db_admin_pass" {
  sensitive = true
}
variable "pg_bases" {
  default = []
}
variable "pg_users" {
  default = []
}
variable "cluster_ipv4_range" {
  default = "10.100.0.0/19"
}
variable "service_ipv4_range" {
  default = "10.254.0.0/19"
}
variable "k8s_vpc_v4_cidr_blocks" {
  default = ["192.168.10.96/28"]
}
variable "grafana_admin_pass" {
  description = "Пароль для grafana"
  sensitive = true
}
variable "prometheus_admin_pass" {
  description = "Пароль для prometheus"
  sensitive = true
}
