#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."
kubectl rollout status deployment/pod-autoscalers

echo "📈 Current HPA status:"
kubectl get hpa -n "$KEMO_NS"

kubectl get pods -n "$KEMO_NS"
kubectl get svc -n "$KEMO_NS"

echo "🎉 Pod Autoscalers (HPA) demo deployed. Press ctrl-k u to open ${KEMO_DEMO} website."