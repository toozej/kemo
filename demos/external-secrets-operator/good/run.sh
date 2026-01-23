#!/usr/bin/env bash

# Check if External Secrets Operator is installed
if ! kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then
  gum style --foreground yellow "⚠️  External Secrets Operator not found. Installing..."
  helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1
  helm repo update >/dev/null 2>&1
  helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace >/dev/null 2>&1
  gum style --foreground green "✅ External Secrets Operator installed"
fi

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."
kubectl rollout status deployment/external-secrets-operator -n external-secrets

echo "🔐 ESO resources:"
kubectl get secretstore,externalsecret,secrets -n "$KEMO_NS" 2>/dev/null || true

kubectl get pods -n "$KEMO_NS"
kubectl get svc -n "$KEMO_NS"

echo "🎉 External Secrets Operator demo deployed. Press ctrl-k u to open ${KEMO_DEMO} website."