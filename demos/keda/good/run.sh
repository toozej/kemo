#!/usr/bin/env bash

# Check if KEDA is installed
if ! kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
  gum style --foreground yellow "⚠️  KEDA not found. Installing..."
  helm repo add kedacore https://kedacore.github.io/charts >/dev/null 2>&1
  helm repo update >/dev/null 2>&1
  helm install keda kedacore/keda -n keda --create-namespace >/dev/null 2>&1
  gum style --foreground green "✅ KEDA installed"
fi

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."
kubectl rollout status deployment/keda -n keda

echo "📈 KEDA ScaledObjects:"
kubectl get scaledobjects -n "$KEMO_NS" 2>/dev/null || true

kubectl get pods -n "$KEMO_NS"
kubectl get svc -n "$KEMO_NS"

echo "🎉 KEDA demo deployed. Press ctrl-k u to open ${KEMO_DEMO} website."