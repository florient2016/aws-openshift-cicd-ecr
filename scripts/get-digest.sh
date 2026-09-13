#!/usr/bin/env bash
# Récupère le digest produit par le dernier PipelineRun.
set -euo pipefail
TF="$(cd "$(dirname "$0")/../terraform" && pwd)"
NS=$(cd "$TF" && terraform output -raw ci_namespace)
IMAGE=$(cd "$TF" && terraform output -raw image)
PR=$(oc -n "$NS" get pipelinerun --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
DIGEST=$(oc -n "$NS" get pipelinerun "$PR" -o jsonpath='{.status.results[?(@.name=="DIGEST")].value}')
echo "PipelineRun : $PR"
echo "Image (à mettre dans gitops/deployment.yaml) :"
echo "  ${IMAGE}@${DIGEST}"
