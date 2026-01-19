#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kubernetes Fundamentals - Broken Demo
# Demonstrates what happens when the runtime CANNOT reconcile
# ============================================================================

gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  --margin "1" \
  "🔴 Kubernetes Fundamentals - BROKEN Demo" \
  "" \
  "This demo shows what happens when the runtime" \
  "CANNOT reconcile to the desired state." \
  "" \
  "We're using a non-existent image tag to break things."

gum confirm "Apply the broken manifests?" || exit 0

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
  kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied (intent declared)"

echo ""
gum style --foreground 220 "⏳ Waiting for rollout (this will fail)..."
echo ""

# Don't use set -e here since we expect failure
kubectl rollout status deployment/k8s-intro -n "$KEMO_NS" --timeout=30s || true

echo ""
gum style \
  --border rounded \
  --border-foreground 196 \
  --padding "1 2" \
  "🔍 What's happening?" \
  "" \
  "The runtime is TRYING to reconcile but failing." \
  "Let's examine the pod status..."

echo ""
gum style --foreground 245 "Pod status:"
kubectl get pods -n "$KEMO_NS" -l app=k8s-intro

echo ""
gum style --foreground 220 "Describe the pod to see the error:"
kubectl describe pods -n "$KEMO_NS" -l app=k8s-intro | grep -A5 "Events:" || true

echo ""
gum style \
  --border rounded \
  --border-foreground 84 \
  --padding "1 2" \
  "📊 spec vs status - Debugging" \
  "" \
  "The status section tells us WHY the runtime" \
  "cannot achieve the spec (desired state)."

echo ""
gum style --foreground 39 "=== Deployment STATUS (shows the problem) ==="
kubectl get deployment k8s-intro -n "$KEMO_NS" -o jsonpath='{.status}' | jq '.'

echo ""
gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  "💡 Key Insight" \
  "" \
  "The image 'nginx:this-tag-does-not-exist-anywhere' doesn't exist." \
  "" \
  "The runtime keeps trying (reconciliation loop) but fails." \
  "This is Kubernetes doing its job - continuously trying to" \
  "match reality to your declared intent." \
  "" \
  "Fix: Update the spec with a valid image tag."
