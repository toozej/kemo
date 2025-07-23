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

# Helper function to ensure tmux uses the Kemo Tmux config file
# Usage: tmux_cmd <tmux arguments>
tmux_cmd() {
  tmux -f "$KEMO_TMUX_CONF" "$@"
}

# Clean log function (no colors for file logging)
log_clean() {
  echo "$1" | sed 's/\x1b\[[0-9;]*m//g' >> "$log_file"
}

# Initialize log file
log_clean "📝 [$timestamp] Running step: $step"
log_clean "💬 Command: $*"
log_clean "---"

# Determine Tmux config file location
KEMO_TMUX_CONF="${KEMO_TMUX_CONF:-./kemo-tmux.conf}"
if [[ ! -f "$KEMO_TMUX_CONF" ]]; then
  echo "❌ Kemo Tmux config not found at: $KEMO_TMUX_CONF"
  echo "Please ensure kemo-tmux.conf is available"
  exit 1
fi

# Create tmux session with main panel
gum spin --spinner dot --title "🚀 Starting TUI session..." -- sleep 1
tmux_cmd new-session -d -s "$session_name" -n "$demo - $variant" -x 120 -y 40

# Wait a moment for session to be fully created
sleep 0.5

# Verify session exists before proceeding
if ! tmux_cmd has-session -t "$session_name" 2>/dev/null; then
  echo "❌ Failed to create tmux session"
  exit 1
fi

# Set environment variables for the session
tmux_cmd set-environment -t "$session_name" KEMO_DEMO "$demo"
tmux_cmd set-environment -t "$session_name" KEMO_VARIANT "$variant"
tmux_cmd set-environment -t "$session_name" KEMO_STEP "$step"
tmux_cmd set-environment -t "$session_name" KEMO_LOG_FILE "$log_file"
tmux_cmd set-environment -t "$session_name" KEMO_SESSION "$session_name"

# Create the hotkey script
cat > "/tmp/kemo-hotkeys-$session_name.sh" << 'HOTKEY_EOF'
#!/usr/bin/env bash
# Kemo Demo Hotkey Handler

case "$1" in
  restart)
    gum confirm '🔄 Restart demo?' && {
      kubectl delete all --all -n "$KEMO_DEMO" 2>/dev/null || true
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
    kubectl get pods,svc,deploy -n "$KEMO_DEMO" --no-headers 2>/dev/null || echo 'No resources found'
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
    kubectl logs -f -l app="$KEMO_DEMO" -n "$KEMO_DEMO" 2>/dev/null || {
      gum style --foreground red '❌ No logs available'
      sleep 2
    }
    ;;
  describe)
    resource=$(kubectl get pods,svc,deploy -n "$KEMO_DEMO" -o name 2>/dev/null | gum choose --header '📋 Select resource to describe')
    [[ -n "$resource" ]] && kubectl describe -n "$KEMO_DEMO" "$resource"
    ;;
  help)
    clear
    gum style --foreground cyan --bold '🔑 Kemo TUI Hotkeys'
    echo
    gum style --foreground white 'Ctrl-k r : Restart demo'
    gum style --foreground white 'Ctrl-k n : Next step (if available)'  
    gum style --foreground white 'Ctrl-k s : Show Kubernetes status'
    gum style --foreground white 'Ctrl-k d : Open Kubernetes dashboard'
    gum style --foreground white 'Ctrl-k l : Tail application logs'
    gum style --foreground white 'Ctrl-k i : Describe K8s resource'
    gum style --foreground white 'Ctrl-k h : Show this help'
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
HOTKEY_EOF

chmod +x "/tmp/kemo-hotkeys-$session_name.sh"

# Set up initial pane layout
tmux_cmd select-window -t "$session_name:0"
tmux_cmd split-window -t "$session_name:0" -h -p 30
# After splitting, pane 0.0 is left, 0.1 is right

# Split right pane (0.1) vertically to create 0.2 (bottom right)
tmux_cmd split-window -t "$session_name:0.1" -v -p 50
# After splitting, pane 0.1 is top right, 0.2 is bottom right

# Set up log pane (top right)
tmux_cmd send-keys -t "$session_name:0.1" "echo '📊 Demo Logs'" Enter
tmux_cmd send-keys -t "$session_name:0.1" "echo 'Logs will appear here as the demo runs...'" Enter
tmux_cmd send-keys -t "$session_name:0.1" "tail -f '$log_file'" Enter

# Set up Kubernetes status pane (bottom right)
tmux_cmd send-keys -t "$session_name:0.2" "clear" Enter
tmux_cmd send-keys -t "$session_name:0.2" "gum style --foreground cyan --bold '📊 Kubernetes Status'" Enter
tmux_cmd send-keys -t "$session_name:0.2" "watch -n 2 kubectl get pods,svc,deploy -n '$demo' --no-headers 2>/dev/null || echo 'No resources found'" Enter

# Set up main execution pane (left side)
tmux_cmd send-keys -t "$session_name:0.0" "clear" Enter
tmux_cmd send-keys -t "$session_name:0.0" "gum style --foreground green --bold '🧪 Kemo Demo TUI'" Enter
tmux_cmd send-keys -t "$session_name:0.0" "gum style --foreground cyan 'Demo: $demo/$variant'" Enter
tmux_cmd send-keys -t "$session_name:0.0" "gum style --foreground yellow 'Step: $step'" Enter
tmux_cmd send-keys -t "$session_name:0.0" "echo" Enter
tmux_cmd send-keys -t "$session_name:0.0" "gum style --foreground magenta 'Press Ctrl-k ? for hotkeys help'" Enter
tmux_cmd send-keys -t "$session_name:0.0" "echo" Enter

# Execute the demo step
tmux_cmd send-keys -t "$session_name:0.0" "gum spin --spinner monkey --title 'Executing step...' -- sleep 1" Enter

# Run the actual command
command_str="$*"
tmux_cmd send-keys -t "$session_name:0.0" "$command_str 2>&1 | tee -a '$log_file'" Enter

# Add completion message
tmux_cmd send-keys -t "$session_name:0.0" "echo" Enter
tmux_cmd send-keys -t "$session_name:0.0" "gum style --foreground green '✅ Step \"$step\" completed'" Enter
tmux_cmd send-keys -t "$session_name:0.0" "echo" Enter

# Launch the TUI
gum style --foreground green --bold "🎬 Launching TUI for $demo - $variant"
gum style --foreground yellow "Use 'Ctrl-k ?' to see available hotkeys"
gum style --foreground cyan "Session: $session_name"

# Show spinner before attaching
gum spin --spinner moon --title "Initializing TUI..." -- sleep 2

# Attach to session
tmux_cmd attach-session -t "$session_name"

# Cleanup on exit
log_clean ""
log_clean "✅ Step '$step' session ended at $(date +"%Y-%m-%d %H:%M:%S")"

# Remove hotkey script
rm -f "/tmp/kemo-hotkeys-$session_name.sh"