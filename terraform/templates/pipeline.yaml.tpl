---
apiVersion: v1
kind: Namespace
metadata:
  name: ${ci_namespace}
  labels: { company: itssolutions, activity: cicd-01 }
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${ci_service_account}
  namespace: ${ci_namespace}
---
# ---- Task 1 : récupère la source ----
apiVersion: tekton.dev/v1
kind: Task
metadata: { name: fetch-source, namespace: ${ci_namespace} }
spec:
  params:
    - { name: URL, type: string }
    - { name: REVISION, type: string, default: main }
  workspaces:
    - { name: source }
  steps:
    - name: clone
      image: alpine/git:latest
      script: |
        #!/bin/sh
        set -e
        git clone --depth 1 --branch "$(params.REVISION)" "$(params.URL)" "$(workspaces.source.path)/repo"
        ls -la "$(workspaces.source.path)/repo"
---
# ---- Task 2 : build + push ECR via IRSA (ZÉRO credential statique) ----
apiVersion: tekton.dev/v1
kind: Task
metadata: { name: build-push-ecr, namespace: ${ci_namespace} }
spec:
  params:
    - { name: IMAGE, type: string }        # ${image}
    - { name: TAG, type: string, default: "1.0.0" }
    - { name: CONTEXT, type: string, default: "repo" }
  workspaces:
    - { name: source }
  results:
    - { name: IMAGE_DIGEST, description: "digest sha256 de l'image poussée" }
  volumes:
    - name: creds
      emptyDir: {}
    - name: aws-token
      projected:
        sources:
          - serviceAccountToken: { audience: ${audience}, expirationSeconds: 3600, path: token }
  steps:
    # 2a) token ECR éphémère via IRSA
    - name: ecr-login
      image: public.ecr.aws/aws-cli/aws-cli:latest
      env:
        - { name: HOME, value: /tmp }
        - { name: AWS_REGION, value: ${region} }
        - { name: AWS_ROLE_ARN, value: ${role_arn} }
        - { name: AWS_WEB_IDENTITY_TOKEN_FILE, value: /var/run/secrets/aws/token }
      volumeMounts:
        - { name: creds, mountPath: /creds }
        - { name: aws-token, mountPath: /var/run/secrets/aws, readOnly: true }
      script: |
        #!/bin/sh
        set -e
        aws ecr get-login-password --region "$AWS_REGION" > /creds/token
        echo "OK: token ECR obtenu via IRSA (aucun secret de registry stocké)."
    # 2b) build + push avec buildah
    - name: build-and-push
      image: quay.io/buildah/stable:latest
      workingDir: $(workspaces.source.path)/$(params.CONTEXT)
      volumeMounts:
        - { name: creds, mountPath: /creds }
      script: |
        #!/bin/sh
        set -e
        REG=$(echo "$(params.IMAGE)" | cut -d/ -f1)
        buildah login --username AWS --password "$(cat /creds/token)" "$REG"
        buildah --storage-driver=vfs bud -t "$(params.IMAGE):$(params.TAG)" .
        buildah --storage-driver=vfs push --digestfile /tmp/digest "$(params.IMAGE):$(params.TAG)"
        DIGEST=$(cat /tmp/digest)
        echo "Poussé: $(params.IMAGE):$(params.TAG) @ $DIGEST"
        printf '%s' "$DIGEST" > "$(results.IMAGE_DIGEST.path)"
---
# ---- Pipeline ----
apiVersion: tekton.dev/v1
kind: Pipeline
metadata: { name: build-and-push, namespace: ${ci_namespace} }
spec:
  params:
    - { name: GIT_URL, type: string }
    - { name: GIT_REVISION, type: string, default: main }
    - { name: IMAGE, type: string }
    - { name: TAG, type: string, default: "1.0.0" }
  workspaces:
    - { name: shared }
  results:
    - { name: DIGEST, value: "$(tasks.build.results.IMAGE_DIGEST)" }
  tasks:
    - name: fetch
      taskRef: { name: fetch-source }
      params:
        - { name: URL, value: "$(params.GIT_URL)" }
        - { name: REVISION, value: "$(params.GIT_REVISION)" }
      workspaces:
        - { name: source, workspace: shared }
    - name: build
      runAfter: [fetch]
      taskRef: { name: build-push-ecr }
      params:
        - { name: IMAGE, value: "$(params.IMAGE)" }
        - { name: TAG, value: "$(params.TAG)" }
      workspaces:
        - { name: source, workspace: shared }
