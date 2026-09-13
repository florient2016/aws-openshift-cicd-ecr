# CICD-01 — Chaîne d'image zéro-credential : Tekton → ECR (IRSA) → Argo CD par digest + gate — itssolutions

Pipeline qui build une image et la pousse sur **ECR sans aucun credential de registry statique**
(le SA Tekton assume un rôle IAM via OIDC/STS → token ECR éphémère). Déploiement **GitOps**
(Argo CD, pull-based) **par digest immuable**. Une `ValidatingAdmissionPolicy` **refuse toute
image hors de notre ECR**.

## Dépendances
- Opérateurs **OpenShift Pipelines** (Tekton) et **OpenShift GitOps** (Argo CD) installés.
- Un **repo Git** (ex. ton GitLab) pour `app/` (source) + `gitops/` (manifests kustomize).
- **OCP ≥ 4.17** pour `ValidatingAdmissionPolicy` GA (sur 4.16 : `v1` → `v1beta1`).
- `terraform`, credentials AWS (ECR + IAM), `oc`.

## Les 4 mécaniques
1. **Push ECR sans clé** : SA `cicd:ci-pipeline` → `AssumeRoleWithWebIdentity` → `aws ecr get-login-password` → `buildah login`.
2. **ECR immutable + scan-on-push** (Terraform).
3. **Argo CD déploie par digest** (`image: …@sha256:…`), self-heal.
4. **Admission gate** : `ValidatingAdmissionPolicy` refuse tout `image` ne commençant pas par `<acct>.dkr.ecr.<region>.amazonaws.com/`.

## Déploiement
```bash
# 0) pousse app/ et gitops/ dans ton repo Git
cd terraform
cat > terraform.tfvars <<EOF
region          = "us-east-1"
#oc get authentication cluster -o jsonpath='{.spec.serviceAccountIssuer}'
oidc_issuer_url = "https://rh-oidc.s3.us-east-1.amazonaws.com/xxxxxxxx"
git_repo_url    = "https://gitlab.com/<toi>/cicd-01.git"
EOF
terraform init && terraform apply     # ECR + IAM + rend rendered/*.yaml

# 1) Pipeline + SCC buildah pour le SA
oc apply -f rendered/pipeline.yaml
oc adm policy add-scc-to-user pipelines-scc -z ci-pipeline -n cicd

# 2) Build + push (IRSA)
bash ../scripts/run-pipeline.sh
oc -n cicd get pipelinerun -w          # attendre Succeeded
bash ../scripts/get-digest.sh          # -> <image>@sha256:<digest>

# 3) Mets ce <image>@sha256:<digest> dans gitops/deployment.yaml, commit + push

# 4) Argo CD déploie
oc apply -f rendered/gitops.yaml
oc -n openshift-gitops get application itssolutions-app -w   # Synced/Healthy

# 5) Gate d'admission
oc apply -f rendered/admission.yaml
```

## Prouver
```bash
# L'app tourne, déployée par digest :
oc -n app-prod get pods -o jsonpath='{.items[*].spec.containers[*].image}{"\n"}'

# Ouvrir la page exposée par la Route :
oc -n app-prod get route app -o jsonpath='https://{.spec.host}{"\n"}'

# Le gate refuse une image hors ECR :
bash scripts/test-admission.sh          # docker.io/nginx -> DENIED ✅
```

## Critères d'acceptation
- [ ] PipelineRun `Succeeded`, image poussée sur ECR (visible dans la console AWS ECR + scan lancé)
- [ ] Logs du step `ecr-login` : token obtenu **via IRSA** (aucun Secret de registry)
- [ ] Argo CD `Synced/Healthy`, pods `app-prod` tournent avec `image: …@sha256:…`
- [ ] `test-admission` : `docker.io/nginx` **refusé** par la ValidatingAdmissionPolicy

## Troubleshooting
| Symptôme | Cause | Fix |
|---|---|---|
| build `permission denied` / SCC | SA pas dans `pipelines-scc` | `oc adm policy add-scc-to-user pipelines-scc -z ci-pipeline -n cicd` |
| `ecr-login` `AccessDenied` | trust policy : `sub` ≠ `cicd:ci-pipeline` | vérifier `ci_namespace`/`ci_service_account` (var TF) |
| `Permission denied: '/.aws'` | UID aléatoire OpenShift | `HOME=/tmp` (déjà dans le step) |
| push `tag immutable` en 2e run | ECR IMMUTABLE + même TAG | changer le TAG (`run-pipeline.sh 1.0.1`) |
| Argo `ImagePullBackOff` | digest pas encore poussé / mauvais digest | refaire get-digest, corriger gitops/deployment.yaml |
| `no matches for kind ValidatingAdmissionPolicy` | OCP < 4.17 | passer `v1` → `v1beta1` dans admission.yaml |
| gate n'active pas | namespace non labellisé | `supply-chain: enforced` sur app-prod (déjà dans gitops/namespace.yaml) |

## Teardown
```bash
oc delete -f rendered/admission.yaml -f rendered/gitops.yaml -f rendered/pipeline.yaml
oc delete ns app-prod --ignore-not-found
cd terraform && terraform destroy       # force_delete purge l'ECR
```
Filet de secours par tags : `company=itssolutions`, `activity=cicd-01`, `managed-by=terraform`.

> Windows : voir `scripts/windows.ps1`.
