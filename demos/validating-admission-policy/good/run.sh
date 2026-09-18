#!/usr/bin/env bash

set -euo pipefail
kubectl label namespace "$KEMO_NS" \
    kemo.example.com/policy-demo=validating-admission-policy \
    --overwrite
kubectl apply -f policy.yaml
kubectl apply -f binding.yaml

kubectl apply -n "$KEMO_NS" --kustomize='.'
kubectl wait --for=condition=Available deployment/policy-compliant -n "$KEMO_NS" --timeout=120s

if kubectl apply -n "$KEMO_NS" -f bad-deployment.yaml; then
    echo "The API server allowed the noncompliant Deployment."
    exit 1
fi
echo "The API server rejected the noncompliant Deployment as expected."
kubectl get validatingadmissionpolicies,validatingadmissionpolicybindings
