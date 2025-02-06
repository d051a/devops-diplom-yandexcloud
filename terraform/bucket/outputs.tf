// Вывод access_key, secret_key и bucket_name
output "access_key" {
  value = yandex_iam_service_account_static_access_key.sa-static-key.access_key
}

output "secret_key" {
  value = yandex_iam_service_account_static_access_key.sa-static-key.secret_key
  sensitive = true
}

output "bucket_name" {
  value = yandex_storage_bucket.test.bucket
}