variable "resource_group_name" {
  type    = string
  default = "tp-devsecops-rg"
}
variable "azure_region" {
  type    = string
  default = "West Europe"
}
variable "app_name" {
  type    = string
  default = "tp-devsecops-prod"
}
variable "docker_image" {
  type = string
}
variable "docker_image_tag" {
  type    = string
  default = "latest"
}
variable "registry_url" {
  type = string
}
variable "registry_user" {
  type      = string
  sensitive = true
}
variable "registry_password" {
  type      = string
  sensitive = true
}

variable "mongo_db_uri" {
  type        = string
  description = "MongoDB Connection URI"
  sensitive   = true
}

variable "jwt_secret" {
  type        = string
  description = "JSON Web Token string"
  sensitive   = true
}

variable "jwt_refresh_secret" {
  type        = string
  description = "JSON Web Token Refresh string"
  sensitive   = true
}

variable "secret_password" {
  type        = string
  description = "Secret password for Admin creation"
  sensitive   = true
}

variable "aes_key" {
  type        = string
  description = "64-character hex key for symmetric AES encryption"
  sensitive   = true
}