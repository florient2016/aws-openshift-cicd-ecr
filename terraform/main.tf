data "aws_caller_identity" "current" {}

locals {
  oidc_host = replace(var.oidc_issuer_url, "https://", "")
  registry  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repo_name}"
}

# ---------- ECR : tags immuables + scan-on-push ----------
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  image_scanning_configuration { scan_on_push = true }
}

# ---------- IAM policy : push/pull scoping + auth token ----------
resource "aws_iam_policy" "ci_ecr" {
  name = "itssolutions-cicd01-ecr"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*" # action account-level, ne peut pas être scopée au repo
      },
      {
        Sid    = "EcrPushPullThisRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
          "ecr:PutImage", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

# ---------- IAM role fédéré OIDC pour le SA du pipeline ----------
resource "aws_iam_role" "ci" {
  name = "itssolutions-cicd01-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_host}" }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = {
        "${local.oidc_host}:sub" = "system:serviceaccount:${var.ci_namespace}:${var.ci_service_account}"
        "${local.oidc_host}:aud" = var.token_audience
      } }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ci" {
  role       = aws_iam_role.ci.name
  policy_arn = aws_iam_policy.ci_ecr.arn
}

# ---------- Manifests rendus ----------
locals {
  vars = {
    ci_namespace       = var.ci_namespace
    ci_service_account = var.ci_service_account
    app_namespace      = var.app_namespace
    role_arn           = aws_iam_role.ci.arn
    region             = var.region
    audience           = var.token_audience
    registry           = local.registry
    image              = local.image
    git_repo_url       = var.git_repo_url
    git_revision       = var.git_revision
    gitops_path        = var.gitops_path
  }
}

resource "local_file" "pipeline" {
  filename = "${path.module}/rendered/pipeline.yaml"
  content  = templatefile("${path.module}/templates/pipeline.yaml.tpl", local.vars)
}

resource "local_file" "gitops" {
  filename = "${path.module}/rendered/gitops.yaml"
  content  = templatefile("${path.module}/templates/gitops.yaml.tpl", local.vars)
}

resource "local_file" "admission" {
  filename = "${path.module}/rendered/admission.yaml"
  content  = templatefile("${path.module}/templates/admission.yaml.tpl", local.vars)
}
