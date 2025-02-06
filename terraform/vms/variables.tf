variable "access_key" {
  description = "Access key for S3 backend"
  type        = string
  default     = null
}

variable "secret_key" {
  description = "Secret key for S3 backend"
  type        = string
  default     = null
}

variable "yc_token" {
  description = "Yandex Cloud IAM token"
  type        = string
  default     = null
}


variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "default_zone" {
  type        = string
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "bucket_name" {
  type        = string
}
