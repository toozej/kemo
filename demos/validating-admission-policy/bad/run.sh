#!/usr/bin/env bash

set -euo pipefail
kubectl label namespace "$KEMO_NS" \
    kemo.example.com/policy-demo=validating-admission-policy-bad \
    --overwrite
kubectl apply -f policy.yaml
kubectl apply -f binding.yaml

if kubectl apply -n "$KEMO_NS" --kustomize='.'; then
    echo "The API server allowed the noncompliant Deployment."
    exit 1
fi
echo "The API server rejected the noncompliant Deployment as expected."
kubectl get validatingadmissionpolicies,validatingadmissionpolicybindings
