#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <demo> <variant> <step> <command...>"
  exit 1
fi

demo=$1
variant=$2
step=$3
shift 3

log_dir="demos/$demo/$variant/.logs"
mkdir -p "$log_dir"

# Ensure .gitignore exists
ignorefile="demos/$demo/$variant/.gitignore"
if [[ ! -f "$ignorefile" ]]; then
  echo ".logs/" > "$ignorefile"
fi

log_file="$log_dir/$step.log"
timestamp=$(date +"%Y-%m-%d %H:%M:%S")
session_name="kemo-$demo-$variant-$(date +%s)"

# Clean log function (no colors for file logging)
log_clean() {
  echo "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$log_file"
}

# Initialize log file
log_clean "📝 [$timestamp] Running step: $step"
log_clean "💬 Command: $*"
log_clean "---"

# Create tmux session with main panel
gum spin --spinner dot --title "🚀 Starting TUI session..." -- sleep 1

tmux new-session -d -s "$session_name" -x 120 -y 40

# Set up key bindings and environment
tmux send-keys -t "$session_name" "export KEMO_DEMO='$demo'" Enter
tmux send-keys -t "$session_name" "export KEMO_VARIANT='$variant'" Enter
tmux send-keys -t "$session_name" "export KEMO_STEP='$step'" Enter
tmux send-keys -t "$session_name" "export KEMO_LOG_FILE='$log_file'" Enter
tmux send-keys -t "$session_name" "export KEMO_SESSION='$session_name'" Enter

# Create hotkey script in session
tmux send-keys -t "$session_name" "cat > /tmp/kemo-hotkeys-$session_name.sh << 'HOTKEY_EOF'
#!/usr/bin/env bash
case \"\$1\" in
  restart)
    gum confirm '🔄 Restart demo?' && {
      kubectl delete all --all -n \$KEMO_DEMO 2>/dev/null || true
      just apply-manifests \$KEMO_DEMO \$KEMO_VARIANT
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
    kubectl get pods,svc,deploy -n \$KEMO_DEMO --no-headers 2>/dev/null || echo 'No resources found'
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
    kubectl logs -f -l app=\${KEMO_DEMO} -n \$KEMO_DEMO 2>/dev/null || {
      gum style --foreground red '❌ No logs available'
      sleep 2
    }
    ;;
  describe)
    resource=\$(kubectl get pods,svc,deploy -n \$KEMO_DEMO -o name 2>/dev/null | gum choose --header '📋 Select resource to describe')
    [[ -n \"\$resource\" ]] && kubectl describe -n \$KEMO_DEMO \"\$resource\"
    ;;
  help)
    clear
    gum style --foreground cyan --bold '🔑 Kemo TUI Hotkeys'
    echo
    gum style --foreground green 'Ctrl-k r' --foreground white ' : Restart demo'
    gum style --foreground green 'Ctrl-k n' --foreground white ' : Next step (if available)'  
    gum style --foreground green 'Ctrl-k s' --foreground white ' : Show Kubernetes status'
    gum style --foreground green 'Ctrl-k d' --foreground white ' : Open Kubernetes dashboard'
    gum style --foreground green 'Ctrl-k l' --foreground white ' : Tail application logs'
    gum style --foreground green 'Ctrl-k i' --foreground white ' : Describe K8s resource'
    gum style --foreground green 'Ctrl-k h' --foreground white ' : Show this help'
    gum style --foreground green 'Ctrl-k q' --foreground white ' : Quit demo'
    echo
    gum style --foreground cyan 'Panel Management:'
    gum style --foreground green 'Ctrl-k v' --foreground white ' : Split vertically'
    gum style --foreground green 'Ctrl-k x' --foreground white ' : Split horizontally'  
    gum style --foreground green 'Ctrl-k c' --foreground white ' : Close current pane'
    gum style --foreground green 'Ctrl-k w' --foreground white ' : Watch pods in new pane'
    gum style --foreground green 'Ctrl-k e' --foreground white ' : Watch events in new pane'
    echo
    gum style --foreground yellow 'Press any key to continue...'
    read -n 1
    ;;
  *)
    gum style --foreground red \"Unknown action: \$1\"
    ;;
esac
HOTKEY_EOF
chmod +x /tmp/kemo-hotkeys-$session_name.sh" Enter

# Set up tmux key bindings
tmux bind-key -T prefix r run-shell "/tmp/kemo-hotkeys-$session_name.sh restart"
tmux bind-key -T prefix n run-shell "/tmp/kemo-hotkeys-$session_name.sh next-step"  
tmux bind-key -T prefix s run-shell "/tmp/kemo-hotkeys-$session_name.sh k8s-status"
tmux bind-key -T prefix d run-shell "/tmp/kemo-hotkeys-$session_name.sh k8s-dashboard"
tmux bind-key -T prefix l run-shell "/tmp/kemo-hotkeys-$session_name.sh logs"
tmux bind-key -T prefix i run-shell "/tmp/kemo-hotkeys-$session_name.sh describe"
tmux bind-key -T prefix h run-shell "/tmp/kemo-hotkeys-$session_name.sh help"
tmux bind-key -T prefix q confirm-before -p "Quit demo? (y/n)" kill-session
tmux bind-key -T prefix v split-window -h
tmux bind-key -T prefix x split-window -v
tmux bind-key -T prefix c kill-pane
tmux bind-key -T prefix w split-window -h "watch kubectl get pods -n $demo"
tmux bind-key -T prefix e split-window -v "kubectl get events -n $demo --watch"

# Set status bar with helpful info
tmux set-option -t "$session_name" status-right "#[fg=cyan]Demo: $demo/$variant #[fg=yellow]| Ctrl-k h for help"
tmux set-option -t "$session_name" status-right-length 60

# Create initial panes
# Main execution pane (already exists)
tmux split-window -t "$session_name" -h -p 30
tmux select-pane -t "$session_name:0.0"

# Set up log tailing in right pane
tmux send-keys -t "$session_name:0.1" "echo '📊 Demo Logs'" Enter
tmux send-keys -t "$session_name:0.1" "echo 'Logs will appear here as the demo runs...'" Enter
tmux send-keys -t "$session_name:0.1" "tail -f '$log_file'" Enter

# Show welcome message in main pane
tmux send-keys -t "$session_name:0.0" "clear" Enter
tmux send-keys -t "$session_name:0.0" "gum style --foreground green --bold '🧪 Kemo Demo TUI'" Enter
tmux send-keys -t "$session_name:0.0" "gum style --foreground cyan 'Demo: $demo/$variant'" Enter
tmux send-keys -t "$session_name:0.0" "gum style --foreground yellow 'Step: $step'" Enter
tmux send-keys -t "$session_name:0.0" "echo" Enter
tmux send-keys -t "$session_name:0.0" "gum style --foreground magenta 'Press Ctrl-k h for hotkeys help'" Enter
tmux send-keys -t "$session_name:0.0" "echo" Enter

# Execute the actual command with progress indication
tmux send-keys -t "$session_name:0.0" "gum spin --spinner monkey --title 'Executing step...' -- sleep 1" Enter

# Run the command and capture output for logging
command_str="$*"
tmux send-keys -t "$session_name:0.0" "$command_str 2>&1 | tee -a '$log_file'" Enter

# Add completion message
tmux send-keys -t "$session_name:0.0" "echo" Enter
tmux send-keys -t "$session_name:0.0" "gum style --foreground green '✅ Step \"$step\" completed'" Enter
tmux send-keys -t "$session_name:0.0" "echo" Enter

# Attach to session
gum style --foreground green --bold "🎬 Launching TUI for $demo/$variant"
gum style --foreground yellow "Use Ctrl-k h to see available hotkeys"
gum style --foreground cyan "Session: $session_name"

# Show progress bar before attaching
gum progress --from 0 --to 100 --delay 20ms --title "Initializing TUI..." > /dev/null &
sleep 2

tmux attach-session -t "$session_name"

# Cleanup on exit
log_clean ""
log_clean "✅ Step '$step' session ended at $(date +"%Y-%m-%d %H:%M:%S")"

# Remove hotkey script
rm -f "/tmp/kemo-hotkeys-$session_name.sh"