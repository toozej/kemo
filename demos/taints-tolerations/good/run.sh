#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."
kubectl rollout status deployment/taints-tolerations

kubectl get pods -n "$KEMO_NS"
kubectl get svc -n "$KEMO_NS"

echo "🎉 Taints/Tolerations demo deployed. Press ctrl-k u to open ${KEMO_DEMO} website."