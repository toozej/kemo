#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "${KEMO_NS}" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."
kubectl -n "${KEMO_NS}" rollout status deployment/resource-quotas

echo
kubectl get deploy,po,svc,ing -n "${KEMO_NS}"
echo
kubectl get resourcequota,limitrange -n "${KEMO_NS}"

echo "🎉 Demo ready at https://resource-quotas-good.k8s.orb.local"
