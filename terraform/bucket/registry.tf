# Создание Yandex Container Registry
resource "yandex_container_registry" "my_registry" {
  folder_id = var.folder_id
  name      = "my-container-registry"
}

# Создание репозитория внутри YCR
resource "yandex_container_repository" "my_repository" {
  name       = "${yandex_container_registry.my_registry.id}/my_repository"
  depends_on = [yandex_container_registry.my_registry]
}

# Output для получения registry_id
output "registry_id" {
  description = "ID созданного Yandex Container Registry"
  value       = yandex_container_registry.my_registry.id
}