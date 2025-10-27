#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'

gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."
kubectl -n "$KEMO_NS" rollout status deployment/node-selector

echo
kubectl get deploy,po,svc,ing -n "$KEMO_NS"
echo

echo "🎉 Demo ready at https://node-selector-good.k8s.orb.local"
