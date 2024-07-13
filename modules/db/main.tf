terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

data "yandex_resourcemanager_folder" "target_folder" {
  name = var.folder_name
}

// Создаем подсеть для postgresql
resource "yandex_vpc_subnet" "pg-subnet" {
  name           = var.vpc_subnet_name
  zone           = var.zone
  network_id     = var.vpc_network_id
  v4_cidr_blocks = var.vpc_v4_cidr_blocks
  folder_id = data.yandex_resourcemanager_folder.target_folder.id
}

// Создаем postgres cluster
resource "yandex_mdb_postgresql_cluster" "pg-main" {
  environment = "PRESTABLE"
  name        = "otus-project"
  network_id  = var.vpc_network_id
  folder_id = data.yandex_resourcemanager_folder.target_folder.id

  config {
    version = 14
    resources {
      disk_size          = 10
      resource_preset_id = "s2.micro"
      disk_type_id       = "network-hdd"
    }
    postgresql_config = {
      max_connections                   = 395
      enable_parallel_hash              = true
      autovacuum_vacuum_scale_factor    = 0.34
      default_transaction_isolation     = "TRANSACTION_ISOLATION_READ_COMMITTED"
      shared_preload_libraries          = "SHARED_PRELOAD_LIBRARIES_AUTO_EXPLAIN,SHARED_PRELOAD_LIBRARIES_PG_HINT_PLAN"
    }
  }
  host {
    zone      = var.zone
    subnet_id = yandex_vpc_subnet.pg-subnet.id
    assign_public_ip = var.assign_public_ip
  }
}

// Создаем в цикле пользователей БД
resource "yandex_mdb_postgresql_user" "db_users" {
  for_each   = {for v in var.pg_users : v.db_user_name => v}
  cluster_id = yandex_mdb_postgresql_cluster.pg-main.id
  name       = each.value.db_user_name
  password   = each.value.db_user_pass
  conn_limit = each.value.db_conn_limit
}

// Создаем в цикле базы данных
resource "yandex_mdb_postgresql_database" "databases" {
  for_each   = {for v in var.pg_bases : v.db_name => v}
  cluster_id = yandex_mdb_postgresql_cluster.pg-main.id
  name       = each.value.db_name
  owner      = yandex_mdb_postgresql_user.db_users[each.value.db_owner_user_name].name
  lc_collate = "en_US.UTF-8"
  lc_type    = "en_US.UTF-8"
}

//Admin for all DBs
resource "yandex_mdb_postgresql_user" "db_admin" {
  depends_on = [yandex_mdb_postgresql_database.databases]
  cluster_id = yandex_mdb_postgresql_cluster.pg-main.id
  name       = "db_admin"
  password   = var.db_admin_pass
  conn_limit = 30
  // Даем права владельца для каждой БД
  grants = sort(concat(["mdb_admin"], [for v in var.pg_users : v.db_user_name]))
  dynamic "permission" {
    for_each = var.pg_bases
    content {
      database_name = permission.value.db_name
    }
  }
}




