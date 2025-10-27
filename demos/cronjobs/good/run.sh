#!/usr/bin/env bash
set -euo pipefail

gum spin --spinner dot --title "🔌 Applying manifests..." -- \
kubectl apply -n "$KEMO_NS" --kustomize='.'
gum style --foreground green "✅ Manifests applied successfully"

echo "📅 Listing CronJob, Jobs, and Pods (label app=cronjobs)..."
kubectl get cronjob,job,pod -l app=cronjobs -n "$KEMO_NS"
echo

echo "🚀 Triggering an immediate manual run from the CronJob for demo visibility..."
MANUAL="cronjobs-manual-$(date +%s)"
kubectl -n "$KEMO_NS" create job "$MANUAL" --from=cronjob/cronjobs

echo "⏳ Waiting for manual Job to complete..."
kubectl -n "$KEMO_NS" wait --for=condition=complete job/"$MANUAL" --timeout=180s
echo

echo "📊 Recent Jobs and Pods for manual run:"
kubectl get job,pod -l job-name="$MANUAL" -n "$KEMO_NS"
echo

echo "📜 Logs from manual job pods:"
for p in $(kubectl get pods -n "$KEMO_NS" -l job-name="$MANUAL" -o name); do
  echo "---- logs for $p ----"
  kubectl logs -n "$KEMO_NS" "$p"
done

echo "🎉 CronJob is scheduled (every minute with concurrencyPolicy=Forbid). Manual run '$MANUAL' completed."