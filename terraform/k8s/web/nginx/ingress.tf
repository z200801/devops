resource "kubernetes_service_v1" "nginx_ingress_svc" {
  metadata {
    name      = "nginx-ingress-svc"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  spec {
    selector = {
      app = "nginx"
    }
    session_affinity = "ClientIP"
    port {
      port        = var.service.port
      # target_port = 80
      protocol    = "TCP"
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "nginx" {
  wait_for_load_balancer = true
  metadata {
    name      = "nginx-ingress"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }
  spec {
    rule {
      http {
        path {
          path = "/*"
          backend {
            service {
              name = kubernetes_service_v1.nginx_ingress_svc.metadata.0.name
              port { number = var.service.port }
            }
          }
        }
      }
    }
  }
}


# Display load balancer hostname
output "load_balancer_hostname" {
  value = kubernetes_ingress_v1.nginx.status.0.load_balancer.0.ingress.0.hostname
}

# Display load balancer IP 
output "load_balancer_ip" {
  value = kubernetes_ingress_v1.nginx.status.0.load_balancer.0.ingress.0.ip
}

output "load_balancer_port" {
  value = kubernetes_service_v1.nginx_ingress_svc.spec[0].port[0].node_port
}