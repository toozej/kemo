#!/usr/bin/env bash

echo "👀 Observing rollout status..."

kubectl rollout status deployment/hello-world

kubectl get pods -n $KEMO_NS

kubectl get svc -n $KEMO_NS

echo "🎉 Demo complete! Your Hello World app is now live."