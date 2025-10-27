#!/usr/bin/env bash

set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."
kubectl rollout status -n "$KEMO_NS" statefulset/statefulsets

echo
kubectl get sts -n "$KEMO_NS"
kubectl get pods -n "$KEMO_NS"
kubectl get svc -n "$KEMO_NS"

echo
echo "🎉 The StatefulSet demo is available at https://statefulsets-good.k8s.orb.local"