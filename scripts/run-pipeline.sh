#!/usr/bin/env bash
# Lance un PipelineRun Tekton (build + push ECR via IRSA).
set -euo pipefail
TF="$(cd "$(dirname "$0")/../terraform" && pwd)"
NS=$(cd "$TF" && terraform output -raw ci_namespace)
SA=$(cd "$TF" && terraform output -raw ci_service_account)
IMAGE=$(cd "$TF" && terraform output -raw image)
GIT_URL=$(cd "$TF" && terraform output -raw git_repo_url)
GIT_REV=$(cd "$TF" && terraform output -raw git_revision)
TAG=${1:-1.0.0}

oc create -n "$NS" -f - <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata: { generateName: build-and-push-, namespace: $NS }
spec:
  pipelineRef: { name: build-and-push }
  taskRunTemplate: { serviceAccountName: $SA }
  params:
    - { name: GIT_URL, value: "$GIT_URL" }
    - { name: GIT_REVISION, value: "$GIT_REV" }
    - { name: IMAGE, value: "$IMAGE" }
    - { name: TAG, value: "$TAG" }
  workspaces:
    - name: shared
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          storageClassName: gp3-csi
          resources: { requests: { storage: 1Gi } }
YAML
echo "PipelineRun créé. Suivi :  oc -n $NS get pipelinerun -w   (ou: tkn pr logs -f -n $NS)"
