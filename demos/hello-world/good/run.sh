#!/usr/bin/env bash

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "👀 Observing rollout status..."

kubectl rollout status deployment/hello-world

kubectl get pods -n $KEMO_NS

kubectl get svc -n $KEMO_NS

echo "🎉 Your Hello World app is now live. Press ctrl-k u to open ${KEMO_DEMO} website."