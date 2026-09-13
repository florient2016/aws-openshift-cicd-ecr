# Argo CD déploie l'app par digest depuis Git (pull-based, self-heal).
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: itssolutions-app
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: ${git_repo_url}
    targetRevision: ${git_revision}
    path: ${gitops_path}
  destination:
    server: https://kubernetes.default.svc
    namespace: ${app_namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
