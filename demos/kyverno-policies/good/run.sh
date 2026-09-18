#!/usr/bin/env bash

set -euo pipefail
project_root=$(git rev-parse --show-toplevel)
(cd "$project_root" && just install-kyverno)

kubectl apply -n "$KEMO_NS" -f policy.yaml

kubectl apply -n "$KEMO_NS" --kustomize='.'
kubectl wait --for=condition=Available deployment/policy-compliant -n "$KEMO_NS" --timeout=120s

if kubectl apply -n "$KEMO_NS" -f bad-deployment.yaml; then
    echo "Kyverno allowed the noncompliant Deployment."
    exit 1
fi
echo "Kyverno rejected the noncompliant Deployment as expected."
kubectl get policy,deployments -n "$KEMO_NS"
