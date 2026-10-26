###########################################
# Kubernetes resources (ServiceAccount, Deployment, Service, Ingress)
###########################################

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = local.service_account_name
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.irsa.arn
    }
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
    labels = {
      app = local.app_label
    }
  }

  wait_for_rollout = var.wait_for_rollout

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = local.app_label
      }
    }

    template {
      metadata {
        labels = {
          app = local.app_label
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.this.metadata[0].name

        container {
          name  = var.service_name
          image = local.container_image

          port {
            container_port = var.container_port
          }

          resources {
            requests = var.resources_requests
            limits   = var.resources_limits
          }

          dynamic "env" {
            for_each = var.env
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = var.service_name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = local.app_label
    }

    type = var.service_type

    port {
      port        = var.service_port
      target_port = var.container_port
    }
  }
}

resource "kubernetes_ingress_v1" "this" {
  count = var.create_ingress ? 1 : 0

  metadata {
    name        = var.service_name
    namespace   = var.namespace
    annotations = var.ingress_annotations
  }

  spec {
    ingress_class_name = var.ingress_class_name

    rule {
      host = var.ingress_host != "" ? var.ingress_host : null

      http {
        path {
          path      = var.ingress_path
          path_type = var.ingress_path_type

          backend {
            service {
              name = kubernetes_service_v1.this.metadata[0].name
              port {
                number = var.service_port
              }
            }
          }
        }
      }
    }
  }
}
