variable "region" {
  type    = string
  default = "us-east-1"
}

variable "oidc_issuer_url" {
  type        = string
  description = "OIDC issuer du cluster. oc get authentication cluster -o jsonpath='{.spec.serviceAccountIssuer}'"
}

variable "token_audience" {
  type    = string
  default = "openshift"
}

variable "ci_namespace" {
  type    = string
  default = "cicd"
}

variable "ci_service_account" {
  type        = string
  default     = "ci-pipeline"
  description = "SA du pipeline Tekton, autorisé à assumer le role ECR."
}

variable "ecr_repo_name" {
  type    = string
  default = "itssolutions/app"
}

variable "app_namespace" {
  type    = string
  default = "app-prod"
}

variable "git_repo_url" {
  type        = string
  description = "Repo Git (source app + manifests GitOps). Ex: https://gitlab.com/<you>/cicd-01.git"
}

variable "git_revision" {
  type    = string
  default = "main"
}

variable "gitops_path" {
  type        = string
  default     = "gitops"
  description = "Chemin des manifests kustomize suivis par Argo CD."
}
