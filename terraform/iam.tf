# terraform/iam.tf

# ==================== IAM POLICY POUR ALB CONTROLLER ====================

data "http" "alb_controller_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.0/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.project_name}-alb-controller-policy"
  description = "IAM Policy for AWS Load Balancer Controller"
  policy      = data.http.alb_controller_policy.response_body

  tags = local.common_tags
}

# ==================== IAM ROLE POUR ALB CONTROLLER (IRSA) ====================

module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-alb-controller-role"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

# ==================== PERMISSIONS ADDITIONNELLES POUR ALB ====================

resource "aws_iam_role_policy" "alb_controller_extra" {
  name = "alb-controller-extra-permissions"
  role = module.alb_controller_irsa.iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:GetSecurityGroupsForVpc",
          "elasticloadbalancing:DescribeListenerAttributes",
          "elasticloadbalancing:ModifyListenerAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==================== IAM POLICY POUR PODS (S3 ACCESS) ====================

resource "aws_iam_policy" "s3_access" {
  name        = "${var.project_name}-s3-access-policy"
  description = "IAM Policy for S3 access from Pods"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.products.arn}",
          "${aws_s3_bucket.products.arn}/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

# ==================== IAM USER POUR S3 (BACKEND) ====================

resource "aws_iam_user" "backend_s3" {
  name = "${var.project_name}-backend-s3-user"
  path = "/service-accounts/"

  tags = local.common_tags
}

resource "aws_iam_user_policy_attachment" "backend_s3" {
  user       = aws_iam_user.backend_s3.name
  policy_arn = aws_iam_policy.s3_access.arn
}

resource "aws_iam_access_key" "backend_s3" {
  user = aws_iam_user.backend_s3.name
}
