#!/usr/bin/env bash

set -euo pipefail
project_root=$(git rev-parse --show-toplevel)
(cd "$project_root" && just install-progressive-delivery)

helm upgrade --install flagger-loadtester flagger/loadtester \
    --namespace "$KEMO_NS" \
    --wait \
    --timeout 5m

(cd "$(git rev-parse --show-toplevel)" && just apply-manifests flux-flagger good)

kubectl wait --for=condition=Available deployment/podinfo -n "$KEMO_NS" --timeout=120s
kubectl get canary,pods,services -n "$KEMO_NS"

echo "Run this command to start a canary rollout:"
echo "kubectl set image deployment/podinfo podinfod=ghcr.io/stefanprodan/podinfo:6.7.2 -n $KEMO_NS"
echo "Run this command to watch the rollout:"
echo "kubectl get canary podinfo -n $KEMO_NS --watch"
