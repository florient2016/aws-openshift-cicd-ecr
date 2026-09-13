output "ecr_registry" {
  value = local.registry
}

output "image" {
  value = local.image
}

output "role_arn" {
  value = aws_iam_role.ci.arn
}

output "ci_namespace" {
  value = var.ci_namespace
}

output "ci_service_account" {
  value = var.ci_service_account
}

output "git_repo_url" {
  value = var.git_repo_url
}

output "git_revision" {
  value = var.git_revision
}

output "next_steps" {
  value = <<-EOT

    1) Pousse app/ et gitops/ dans ton repo Git (${var.git_repo_url}).
    2) oc apply -f ${local_file.pipeline.filename}
       oc adm policy add-scc-to-user pipelines-scc -z ${var.ci_service_account} -n ${var.ci_namespace}
    3) Lance le build :  bash scripts/run-pipeline.sh
       -> récupère le digest :  bash scripts/get-digest.sh
    4) Mets le digest dans gitops/deployment.yaml (image: ${local.image}@sha256:...), commit/push.
    5) oc apply -f ${local_file.gitops.filename}          # Argo CD déploie par digest
    6) oc apply -f ${local_file.admission.filename}        # gate : seule notre ECR est admise
  EOT
}
