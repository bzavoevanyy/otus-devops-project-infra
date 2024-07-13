output "vpc_network_id" {
  value = yandex_vpc_network.app-network.id
}
output "vpc_subnet_id" {
  value = yandex_vpc_subnet.app-subnet.id
}
