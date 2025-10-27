#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."

kubectl -n "$KEMO_NS" rollout status deployment/qos-best-effort
kubectl -n "$KEMO_NS" rollout status deployment/qos-burstable
kubectl -n "$KEMO_NS" rollout status deployment/qos-guaranteed

kubectl get deploy,po,svc,ing -n "$KEMO_NS"

echo "🎉 Routes:"
echo " - https://qos-classes-good.k8s.orb.local/best-effort"
echo " - https://qos-classes-good.k8s.orb.local/burstable"
echo " - https://qos-classes-good.k8s.orb.local/guaranteed"
