output "k8s-cluster" {
  value = yandex_kubernetes_cluster.k8s-cluster
}
output "k8s-subnet" {
  value = yandex_vpc_subnet.k8s-subnet
}
output "ci-cd-sa-name" {
  value = yandex_iam_service_account.ci-cd-sa.name
}
output "ci-cd-sa" {
  value = yandex_iam_service_account.ci-cd-sa
}
