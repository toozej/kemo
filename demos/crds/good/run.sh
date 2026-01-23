#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying CRD..." -- \
kubectl apply -f crd.yaml
gum style --foreground green "✅ CRD applied"

gum spin --spinner dot --title "🔌 Applying sample Custom Resource..." -- \
kubectl apply -n "$KEMO_NS" --kustomize=.
gum style --foreground green "✅ Custom Resource applied"

echo "📚 Verifying registration and resources..."
kubectl get crd widgets.kemo.toozej.github.io
kubectl api-resources | grep -E "^widgets\\."
kubectl get widgets -n "$KEMO_NS" -o wide
kubectl get widget/sample-widget -n "$KEMO_NS" -o yaml | sed -n 1,120p

echo "ℹ️  This demo defines a CRD only (no controller). Status fields are informational."
