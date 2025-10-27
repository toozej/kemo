#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying PriorityClasses and workloads..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied"

echo "👀 Observing rollout status..."
kubectl rollout status -n "$KEMO_NS" deployment/priority-high
kubectl rollout status -n "$KEMO_NS" deployment/priority-low

echo "📊 Current objects:"
kubectl get priorityclass
kubectl get pods -n "$KEMO_NS" -o wide
kubectl get svc -n "$KEMO_NS"
kubectl get ingress -n "$KEMO_NS"

echo "🎉 Priority Classes demo exposed at:"
echo "    https://priority-classes-good.k8s.orb.local/high"
echo "    https://priority-classes-good.k8s.orb.local/low"
