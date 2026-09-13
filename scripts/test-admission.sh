#!/usr/bin/env bash
# Prouve le gate : une image hors ECR est REFUSÉE à l'admission dans app-prod.
set -uo pipefail
echo "[test] tenter de déployer une image publique (docker.io/nginx) dans app-prod"
if oc -n app-prod run rogue --image=docker.io/library/nginx:latest --restart=Never 2>&1 | tee /dev/stderr | grep -q "supply-chain"; then
  echo "  RESULT: DENIED ✅ (ValidatingAdmissionPolicy a bloqué l'image hors ECR)"
else
  echo "  RESULT: la commande n'a pas été bloquée — vérifier le label 'supply-chain: enforced' et la version OCP (VAP GA >= 4.17)"
  oc -n app-prod delete pod rogue --ignore-not-found >/dev/null 2>&1 || true
fi
