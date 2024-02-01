provider "kubernetes" {
  config_path = "~/.kube/config" # Path to your kubeconfig file
}

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = "test-nginx"
  }
}

resource "kubernetes_service" "nginx_service" {
  metadata {
    name      = "nginx-svc"
    namespace = kubernetes_namespace.namespace.metadata[0].name
  }
  spec {
    selector = {
      app = "nginx"
    }
    port {
      port = var.service.port
      #target_port = 8080
    }
  }
}


resource "kubernetes_deployment" "nginx_deployment" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      app = "nginx"
    }
  }
  spec {
    replicas = var.deployment.replicas
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          name  = "nginx-container"
          image = "${var.image.name}:${var.image.tag}" #"nginx:latest"

          resources {
            limits = {
              cpu    = var.container_resource_limits.cpu
              memory = var.container_resource_limits.memory
            }
            requests = {
              cpu    = var.container_resource_requests.cpu
              memory = var.container_resource_requests.memory
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80

              http_header {
                name  = "X-Custom-Header"
                value = "Awesome"
              }
            }
            initial_delay_seconds = 3
            period_seconds        = 3
          }
        }
      }
    }
  }
}


