#!/usr/bin/env bash
# Run demo steps inside a tmux pane so output scrolls with the pane.
set -euo pipefail

: "${KEMO_DEMO:?Environment variable KEMO_DEMO must be set}"
: "${KEMO_VARIANT:?Environment variable KEMO_VARIANT must be set}"
: "${KEMO_NS:?Environment variable KEMO_NS must be set}"
: "${SCRIPT_DIR:?Environment variable SCRIPT_DIR must be set}"

case "${1:-status}" in
  status)
    "$SCRIPT_DIR/demo-stepper.sh" status
    ;;
  next)
    "$SCRIPT_DIR/demo-stepper.sh" next
    ;;
  finish)
    "$SCRIPT_DIR/demo-stepper.sh" finish
    ;;
  restart)
    gum style --foreground yellow '🔄 Restarting demo'
    kubectl delete all --all -n "$KEMO_NS" 2>/dev/null || true
    just apply-manifests "$KEMO_DEMO" "$KEMO_VARIANT"
    "$SCRIPT_DIR/demo-stepper.sh" reset
    ;;
  *)
    echo "Unknown stepper action: $1" >&2
    exit 1
    ;;
esac
