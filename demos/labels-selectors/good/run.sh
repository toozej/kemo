#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'

gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."

kubectl -n "$KEMO_NS" rollout status deployment/labels-selectors-v1
kubectl -n "$KEMO_NS" rollout status deployment/labels-selectors-v2

kubectl get deploy,po,svc,ing -n "$KEMO_NS"

echo "🎉 Access the apps at:"
echo "   - https://labels-selectors-good.k8s.orb.local/v1"
echo "   - https://labels-selectors-good.k8s.orb.local/v2"