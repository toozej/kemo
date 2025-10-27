#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."

kubectl rollout status deployment/blue
kubectl rollout status deployment/green

kubectl get pods -n "$KEMO_NS"
kubectl get svc -n "$KEMO_NS"
kubectl get ingress -n "$KEMO_NS"

echo "🎉 Blue/Green app exposed at:"
echo "    https://blue-green-good.k8s.orb.local/blue"
echo "    https://blue-green-good.k8s.orb.local/green"
