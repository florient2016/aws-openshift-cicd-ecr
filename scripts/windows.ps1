# CICD-01 — notes Windows (PowerShell)
oc get authentication cluster -o "jsonpath={.spec.serviceAccountIssuer}"

# SCC pour le SA du pipeline (buildah) :
oc adm policy add-scc-to-user pipelines-scc -z ci-pipeline -n cicd

# Lancer le build : réutiliser les valeurs de 'terraform output' puis 'oc create -f pipelinerun.yaml'
# Suivre : oc -n cicd get pipelinerun -w   (ou tkn pr logs -f -n cicd)
