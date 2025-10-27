#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'

gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."

kubectl -n "$KEMO_NS" rollout status deployment/container-types

kubectl get deploy,po,svc,ing -n "$KEMO_NS"

echo "🎉 Demo reachable at https://container-types-good.k8s.orb.local"