output "production_url" {
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
  description = "URL de l'application en production"
}