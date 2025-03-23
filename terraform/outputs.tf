output "wordpress_ingress_host" {
  description = "Hostname para acessar o WordPress"
  value       = kubernetes_ingress_v1.wordpress_ingress.spec[0].rule[0].host
}

output "wordpress_service_name" {
  description = "Nome do serviço WordPress"
  value       = kubernetes_service.wordpress.metadata[0].name
}

output "mysql_service_name" {
  description = "Nome do serviço MySQL"
  value       = kubernetes_service.mysql.metadata[0].name
} 