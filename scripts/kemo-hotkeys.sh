#!/usr/bin/env bash
# Kemo Demo Hotkey Handler

# Check if required environment variables are set
: "${KEMO_DEMO:?Environment variable KEMO_DEMO must be set}"
: "${KEMO_VARIANT:?Environment variable KEMO_VARIANT must be set}"
: "${KEMO_NS:?Environment variable KEMO_NS must be set}"

run_in_stepper() {
  local action=$1

  if [[ -z "${KEMO_STEPPER_PANE:-}" ]] || ! tmux display-message -p -t "$KEMO_STEPPER_PANE" '#{pane_id}' >/dev/null 2>&1; then
    tmux display-message 'Stepper pane is unavailable'
    return 1
  fi

  if ! tmux respawn-pane -t "$KEMO_STEPPER_PANE" "$SCRIPT_DIR/kemo-stepper-pane.sh $action" >/dev/null 2>&1; then
    tmux display-message 'A demo step is already running'
    return 1
  fi

  tmux select-pane -t "$KEMO_STEPPER_PANE"
}

case "$1" in
  restart)
    run_in_stepper restart
    ;;
  next-step)
    run_in_stepper next
    ;;
  finish)
    run_in_stepper finish
    ;;
  k8s-status)
    clear
    gum style --foreground cyan --bold '📊 Kubernetes Status'
    echo
    kubectl get pods,svc,deploy -n "$KEMO_NS" --no-headers 2>/dev/null || echo 'No resources found'
    echo
    gum style --foreground yellow 'Press any key to continue...'
    read -r -n 1
    ;;
  k8s-dashboard)
    gum style --foreground blue '🌐 Opening Headlamp dashboard via HTTPS ingress...'
    # Determine provider
    provider="${KEMO_PROVIDER:-}"
    if [[ -z "$provider" ]]; then
      current_context="$(kubectl config current-context 2>/dev/null || echo "")"
      if [[ "$current_context" == "orbstack" ]]; then
        provider="orbstack"
      else
        provider="minikube"
      fi
    fi
    if [[ "$provider" == "orbstack" ]]; then
      dashboard_url='https://dashboard.k8s.orb.local/'
    else
      dashboard_url='https://dashboard.k8s.mk.local/'
    fi
    token=$(kubectl -n headlamp create token headlamp-admin 2>/dev/null)
    if [[ -n "$token" ]]; then
      if command -v pbcopy >/dev/null; then
        echo "$token" | pbcopy
        gum style --foreground green '✅ Bearer token copied to clipboard (pbcopy)'
      elif command -v xclip >/dev/null; then
        echo "$token" | xclip -selection clipboard
        gum style --foreground green '✅ Bearer token copied to clipboard (xclip)'
      else
        gum style --foreground yellow "📋 Bearer token: $token"
      fi
    fi
    if command -v open >/dev/null; then
      open "$dashboard_url"
    elif command -v xdg-open >/dev/null; then
      xdg-open "$dashboard_url"
    else
      gum style --foreground yellow "📋 Dashboard URL: $dashboard_url"
    fi
    gum style --foreground cyan 'Paste the token into Headlamp to authenticate.'
    ;;
  logs)
    kubectl logs -f -n "$KEMO_NS" 2>/dev/null || {
      gum style --foreground red '❌ No logs available'
      sleep 2
    }
    ;;
  open-url)
    gum style --foreground blue '🌐 Opening demo URL ...'
    # Provider-specific HTTPS ingress URL
    provider="${KEMO_PROVIDER:-}"
    if [[ -z "$provider" ]]; then
      current_context="$(kubectl config current-context 2>/dev/null || echo "")"
      if [[ "$current_context" == "orbstack" ]]; then
        provider="orbstack"
      else
        provider="minikube"
      fi
    fi
    if [[ "$provider" == "orbstack" ]]; then
      url="https://$KEMO_DEMO-$KEMO_VARIANT.k8s.orb.local/"
    else
      url="https://$KEMO_DEMO-$KEMO_VARIANT.k8s.mk.local/"
    fi
    # Read the URL path from the .url_path file if it exists
    if [ -f "demos/$KEMO_DEMO/$KEMO_VARIANT/.url_path" ]; then
        url_path=$(cat "demos/$KEMO_DEMO/$KEMO_VARIANT/.url_path")
        url="$url$url_path"
    fi
    if command -v open >/dev/null; then
      open "$url"
    elif command -v xdg-open >/dev/null; then
      xdg-open "$url"
    else
      gum style --foreground yellow "📋 Demo URL: $url"
    fi
    ;;
  describe)
    resource=$(kubectl get pods,svc,deploy -n "$KEMO_NS" -o name 2>/dev/null | gum choose --header '📋 Select resource to describe')
    [[ -n "$resource" ]] && kubectl describe -n "$KEMO_NS" "$resource"
    ;;
  help)
    gum style --foreground cyan --bold '🔑 Kemo TUI Hotkeys'
    echo
    gum style --foreground white 'Ctrl-k r : Restart demo'
    gum style --foreground white 'Ctrl-k n : Execute next demo step'
    gum style --foreground white 'Ctrl-k f : Run all remaining steps and keep the lab open'
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
    read -r -n 1
    ;;
  *)
    gum style --foreground red "Unknown action: $1"
    ;;
esac
