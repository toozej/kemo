#!/usr/bin/env bash
# Kemo Demo Hotkey Handler

# Check if required environment variables are set
: "${KEMO_DEMO:?Environment variable KEMO_DEMO must be set}"
: "${KEMO_VARIANT:?Environment variable KEMO_VARIANT must be set}"
: "${KEMO_NS:?Environment variable KEMO_NS must be set}"

case "$1" in
  restart)
    gum confirm '🔄 Restart demo?' && {
      kubectl delete all --all -n "$KEMO_NS" 2>/dev/null || true
      just apply-manifests "$KEMO_DEMO" "$KEMO_VARIANT"
    }
    ;;
  next-step)
    gum style --foreground green '➡️  Moving to next step...'
    # This would be handled by the main demo runner
    ;;
  k8s-status)
    clear
    gum style --foreground cyan --bold '📊 Kubernetes Status'
    echo
    kubectl get pods,svc,deploy -n "$KEMO_NS" --no-headers 2>/dev/null || echo 'No resources found'
    echo
    gum style --foreground yellow 'Press any key to continue...'
    read -n 1
    ;;
  k8s-dashboard)
    gum style --foreground blue '🌐 Opening Kubernetes Dashboard...'
    kubectl proxy --port=8001 >/dev/null 2>&1 &
    sleep 2
    if command -v open >/dev/null; then
      open 'http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/'
    elif command -v xdg-open >/dev/null; then
      xdg-open 'http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/'
    else
      gum style --foreground yellow '📋 Dashboard URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/'
    fi
    ;;
  logs)
    kubectl logs -f -n "$KEMO_NS" 2>/dev/null || {
      gum style --foreground red '❌ No logs available'
      sleep 2
    }
    ;;
  open-url)
    gum style --foreground blue '🌐 Opening Kubernetes Service URL ...'
    if command -v open >/dev/null; then
      open "http://$KEMO_DEMO.$KEMO_DEMO-$KEMO_VARIANT.svc.cluster.local"
    elif command -v xdg-open >/dev/null; then
      xdg-open "http://$KEMO_DEMO.$KEMO_DEMO-$KEMO_VARIANT.svc.cluster.local"
    else
      gum style --foreground yellow "📋 Kubernetes Service URL: http://$KEMO_DEMO.$KEMO_DEMO-$KEMO_VARIANT.svc.cluster.local"
    fi
    ;;
  describe)
    resource=$(kubectl get pods,svc,deploy -n "$KEMO_NS" -o name 2>/dev/null | gum choose --header '📋 Select resource to describe')
    [[ -n "$resource" ]] && kubectl describe -n "$KEMO_NS" "$resource"
    ;;
  help)
    clear
    gum style --foreground cyan --bold '🔑 Kemo TUI Hotkeys'
    echo
    gum style --foreground white 'Ctrl-k r : Restart demo'
    gum style --foreground white 'Ctrl-k n : Next step (if available)'  
    gum style --foreground white 'Ctrl-k s : Show Kubernetes status'
    gum style --foreground white 'Ctrl-k d : Open Kubernetes dashboard'
    gum style --foreground white 'Ctrl-k u : Open application URL'
    gum style --foreground white 'Ctrl-k o : Tail application logs'
    gum style --foreground white 'Ctrl-k i : Describe K8s resource'
    gum style --foreground white 'Ctrl-k ? : Show this help'
    gum style --foreground white 'Ctrl-k q : Quit demo'
    echo
    gum style --foreground cyan 'Panel Management:'
    gum style --foreground white 'Ctrl-k v : Split vertically'
    gum style --foreground white 'Ctrl-k x : Split horizontally'
    gum style --foreground white 'Ctrl-k c : Close current pane'
    gum style --foreground white 'Ctrl-k w : Watch pods in new pane'
    gum style --foreground white 'Ctrl-k e : Watch events in new pane'
    echo
    gum style --foreground yellow 'Press any key to continue...'
    read -n 1
    ;;
  *)
    gum style --foreground red "Unknown action: $1"
    ;;
esac