#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "⏳ Waiting for Job completion..."
kubectl -n "$KEMO_NS" wait --for=condition=complete job/jobs --timeout=180s

echo
kubectl get job,pods -l app=jobs -n "$KEMO_NS"
echo

echo "📜 Collecting logs from Job pods..."
pods=$(kubectl get pods -n "$KEMO_NS" -l job-name=jobs -o name)
for p in $pods; do
  echo "---- logs for $p ----"
  kubectl logs -n "$KEMO_NS" "$p"
done

echo "🎉 Job 'jobs' completed successfully with 3/3 completions."
