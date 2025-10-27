#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'

gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."

kubectl rollout status -n "$KEMO_NS" daemonset/daemonsets

kubectl get ds,pods,svc -n "$KEMO_NS"

echo "🎉 DaemonSet demo is live. Visit https://daemonsets-good.k8s.orb.local"