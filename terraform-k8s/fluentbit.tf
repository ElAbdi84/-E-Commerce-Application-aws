# terraform-k8s/fluentbit.tf
# ============================================================================
# FLUENTBIT - CENTRALISATION DES LOGS VERS CLOUDWATCH
# ============================================================================

# Namespace pour FluentBit
resource "kubernetes_namespace" "logging" {
  metadata {
    name = "logging"
    labels = {
      name = "logging"
    }
  }
}

# ServiceAccount pour FluentBit
resource "kubernetes_service_account" "fluentbit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.logging.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.fluentbit.arn
    }
  }
}

# IAM Role pour FluentBit
resource "aws_iam_role" "fluentbit" {
  name = "${var.project_name}-fluentbit-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:logging:fluent-bit"
        }
      }
    }]
  })
}

# Attach CloudWatch policy
resource "aws_iam_role_policy_attachment" "fluentbit_cloudwatch" {
  role       = aws_iam_role.fluentbit.name
  policy_arn = data.aws_iam_policy.fluentbit_cloudwatch.arn
}

# ConfigMap FluentBit
resource "kubernetes_config_map" "fluentbit_config" {
  metadata {
    name      = "fluent-bit-config"
    namespace = kubernetes_namespace.logging.metadata[0].name
  }

  data = {
    "fluent-bit.conf" = <<-EOT
      [SERVICE]
          Flush         5
          Log_Level     info
          Daemon        off
          Parsers_File  parsers.conf

      [INPUT]
          Name              tail
          Path              /var/log/containers/*backend*.log
          Parser            docker
          Tag               backend.*
          Refresh_Interval  5
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On

      [INPUT]
          Name              tail
          Path              /var/log/containers/*frontend*.log
          Parser            docker
          Tag               frontend.*
          Refresh_Interval  5
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On

      [INPUT]
          Name              tail
          Path              /var/log/containers/*worker*.log
          Parser            docker
          Tag               worker.*
          Refresh_Interval  5
          Mem_Buf_Limit     5MB
          Skip_Long_Lines   On

      [FILTER]
          Name                kubernetes
          Match               *
          Kube_URL            https://kubernetes.default.svc:443
          Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
          Merge_Log           On
          Keep_Log            Off
          K8S-Logging.Parser  On
          K8S-Logging.Exclude On

      [OUTPUT]
          Name                cloudwatch_logs
          Match               backend.*
          region              ${var.aws_region}
          log_group_name      /aws/eks/${var.cluster_name}/backend
          log_stream_prefix   from-fluent-bit-
          auto_create_group   true

      [OUTPUT]
          Name                cloudwatch_logs
          Match               frontend.*
          region              ${var.aws_region}
          log_group_name      /aws/eks/${var.cluster_name}/frontend
          log_stream_prefix   from-fluent-bit-
          auto_create_group   true

      [OUTPUT]
          Name                cloudwatch_logs
          Match               worker.*
          region              ${var.aws_region}
          log_group_name      /aws/eks/${var.cluster_name}/worker
          log_stream_prefix   from-fluent-bit-
          auto_create_group   true
    EOT

    "parsers.conf" = <<-EOT
      [PARSER]
          Name   docker
          Format json
          Time_Key time
          Time_Format %Y-%m-%dT%H:%M:%S.%LZ
    EOT
  }
}

# DaemonSet FluentBit
resource "kubernetes_daemonset" "fluentbit" {
  metadata {
    name      = "fluent-bit"
    namespace = kubernetes_namespace.logging.metadata[0].name
    labels = {
      app = "fluent-bit"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "fluent-bit"
      }
    }

    template {
      metadata {
        labels = {
          app = "fluent-bit"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.fluentbit.metadata[0].name

        container {
          name  = "fluent-bit"
          image = "public.ecr.aws/aws-observability/aws-for-fluent-bit:2.31.12"

          resources {
            limits = {
              memory = "200Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "100Mi"
            }
          }

          volume_mount {
            name       = "config"
            mount_path = "/fluent-bit/etc/"
          }

          volume_mount {
            name       = "varlog"
            mount_path = "/var/log"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.fluentbit_config.metadata[0].name
          }
        }

        volume {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }

        volume {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }

        toleration {
          operator = "Exists"
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map.fluentbit_config,
    kubernetes_service_account.fluentbit
  ]
}

# ClusterRole for FluentBit
resource "kubernetes_cluster_role" "fluentbit" {
  metadata {
    name = "fluent-bit"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding
resource "kubernetes_cluster_role_binding" "fluentbit" {
  metadata {
    name = "fluent-bit"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluentbit.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluentbit.metadata[0].name
    namespace = kubernetes_namespace.logging.metadata[0].name
  }
}
