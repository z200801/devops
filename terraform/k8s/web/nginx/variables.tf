variable "service" {
  type = map(any)
  default = {
    port       = "80"
    targetPort = "80"
  }
}

variable "deployment" {
  description = "Default variable for deployment"
  type        = map(any)
  default = {
    replicas = 2
  }

}
variable "image" {
  type = map(any)
  default = {
    name = "nginx"
    tag  = "latest"
  }
}

variable "container_resource_limits" {
  type = map(any)
  default = {
    cpu    = "0.2"
    memory = "64Mi"
  }
}

variable "container_resource_requests" {
  type = map(any)
  default = {
    cpu    = "0.05"
    memory = "16Mi"
  }
}

