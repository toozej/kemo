#!/usr/bin/env bash

set -euo pipefail
project_root=$(git rev-parse --show-toplevel)
(cd "$project_root" && just install-kyverno)

kubectl apply -n "$KEMO_NS" -f policy.yaml

if kubectl apply -n "$KEMO_NS" --kustomize='.'; then
    echo "Kyverno allowed the noncompliant Deployment."
    exit 1
fi
echo "Kyverno rejected the noncompliant Deployment as expected."
kubectl get policy,deployments -n "$KEMO_NS"
