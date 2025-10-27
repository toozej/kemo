#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'

gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."

kubectl -n "$KEMO_NS" rollout status deployment/volumes

kubectl get deploy,po,svc,ing -n "$KEMO_NS"

echo "🎉 Volumes demo is live at https://volumes-good.k8s.orb.local"
