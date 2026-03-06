# terraform-k8s/kubernetes-resources.tf

# ==================== SECRETS ====================

resource "kubernetes_secret" "db_credentials" {
  metadata {
    name      = "db-credentials"
    namespace = "default"
  }

  data = {
    DB_HOST     = split(":", data.aws_db_instance.main.endpoint)[0]
    DB_USER     = var.db_username
    DB_PASSWORD = var.db_password
    DB_NAME     = var.db_name
    DB_PORT     = "3306"
  }

  type = "Opaque"
}

resource "kubernetes_secret" "jwt_secret" {
  metadata {
    name      = "jwt-secret"
    namespace = "default"
  }

  data = {
    JWT_SECRET = var.jwt_secret
  }

  type = "Opaque"
}

resource "kubernetes_secret" "aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = "default"
  }

  data = {
    AWS_ACCESS_KEY_ID     = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
  }

  type = "Opaque"
}

# ==================== CONFIGMAP ====================

resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "app-config"
    namespace = "default"
  }

  data = {
    NODE_ENV          = var.environment
    AWS_REGION        = var.aws_region
    S3_BUCKET_NAME    = data.aws_s3_bucket.products.id
    SQS_QUEUE_URL     = ""
    BACKEND_PORT      = "5000"
    REACT_APP_API_URL = ""
  }
}

# ==================== DEPLOYMENT BACKEND ====================

resource "kubernetes_deployment" "backend" {
  wait_for_rollout = false
  metadata {
    name      = "backend-deployment"
    namespace = "default"
    
    labels = {
      app  = "backend"
      tier = "api"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app  = "backend"
          tier = "api"
        }
      }

      spec {
        container {
          name  = "backend"
          image = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecommerce-backend:latest"
          
          port {
            container_port = 5000
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.db_credentials.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.jwt_secret.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.aws_credentials.metadata[0].name
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.db_credentials,
    kubernetes_secret.jwt_secret,
    kubernetes_secret.aws_credentials,
    kubernetes_config_map.app_config
  ]
}

# ==================== SERVICE BACKEND ====================

resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend-service"
    namespace = "default"
    
    labels = {
      app  = "backend"
      tier = "api"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "backend"
    }

    port {
      protocol    = "TCP"
      port        = 5000
      target_port = 5000
      name        = "http"
    }
  }

  depends_on = [kubernetes_deployment.backend]
}
# ==================== DEPLOYMENT FRONTEND ====================

resource "kubernetes_deployment" "frontend" {
  wait_for_rollout = false
  metadata {
    name      = "frontend-deployment"
    namespace = "default"
    
    labels = {
      app  = "frontend"
      tier = "web"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app  = "frontend"
          tier = "web"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecommerce-frontend:latest"
          image_pull_policy = "Always"
          port {
            container_port = 80
            name           = "http"
          }

          env {
            name = "REACT_APP_API_URL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.app_config.metadata[0].name
                key  = "REACT_APP_API_URL"
              }
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 20
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "100m"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_config_map.app_config]
}

# ==================== SERVICE FRONTEND ====================

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend-service"
    namespace = "default"
    
    labels = {
      app  = "frontend"
      tier = "web"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "frontend"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
      name        = "http"
    }
  }

  depends_on = [kubernetes_deployment.frontend]
}

# ==================== DEPLOYMENT WORKER ====================

resource "kubernetes_deployment" "worker" {
  wait_for_rollout = false
  metadata {
    name      = "worker-deployment"
    namespace = "default"
    
    labels = {
      app  = "worker"
      tier = "processing"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "worker"
      }
    }

    template {
      metadata {
        labels = {
          app  = "worker"
          tier = "processing"
        }
      }

      spec {
        container {
          name  = "worker"
          image = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/ecommerce-worker:latest"

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.aws_credentials.metadata[0].name
            }
          }

          resources {
            requests = {
              memory = "64Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "128Mi"
              cpu    = "100m"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.aws_credentials,
    kubernetes_config_map.app_config
  ]
}

# ==================== INGRESS (ALB) ====================

# terraform-k8s/kubernetes-resources.tf

resource "kubectl_manifest" "ingress" {
  yaml_body = <<-YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  namespace: default
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/subnets: ${join(",", data.aws_subnets.public.ids)}
    alb.ingress.kubernetes.io/security-groups: ${data.aws_security_group.alb.id}
    alb.ingress.kubernetes.io/healthcheck-path: /api/products
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
    alb.ingress.kubernetes.io/tags: Environment=${var.environment},Project=${var.project_name}
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 5000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80
  YAML

  depends_on = [
    helm_release.alb_controller,
    kubernetes_service.frontend,
    kubernetes_service.backend
  ]
}

# ==================== HPA BACKEND ====================

resource "kubernetes_horizontal_pod_autoscaler_v2" "backend" {
  metadata {
    name      = "backend-hpa"
    namespace = "default"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.backend.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 5

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.backend]
}

# ==================== HPA FRONTEND ====================

resource "kubernetes_horizontal_pod_autoscaler_v2" "frontend" {
  metadata {
    name      = "frontend-hpa"
    namespace = "default"
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.frontend.metadata[0].name
    }

    min_replicas = 2
    max_replicas = 5

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.frontend]
}