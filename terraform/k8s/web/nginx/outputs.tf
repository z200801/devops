output "namespace_name" {
  value = kubernetes_namespace.namespace.metadata[0].name
}

output "nginx_deployment_name" {
  value = kubernetes_deployment.nginx_deployment.metadata.0.name
}

output "nginx_service_name" {
  value = kubernetes_service.nginx_service.metadata.0.name
}