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
tmux_cmd set-environment -t "$session_name" KEMO_NS "$demo-$variant"
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
HOTKEY_EOF
chmod +x "/tmp/kemo-hotkeys-$session_name.sh"

# Set up initial pane layout
tmux_cmd select-window -t "$session_name:0"
tmux_cmd split-window -t "$session_name:0" -h -p 30
# After splitting, pane 0.0 is left, 0.1 is right

# Split left pane (0.0) vertically
tmux_cmd split-window -t "$session_name:0.0" -v -p 15
# After splitting, pane 0.0 is top left, 0.1 is bottom left, 0.2 is right

# Split right pane (0.2) vertically to create 0.3 (bottom right)
tmux_cmd split-window -t "$session_name:0.2" -v -p 50
# After splitting, pane 0.0 is top left, 0.1 is bottom left, pane 0.2 is top right, 0.3 is bottom right

# Create startup scripts for each pane

# Set up log pane (top right)
cat > "/tmp/kemo-log-pane-$session_name.sh" << 'LOG_SCRIPT_EOF'
#!/usr/bin/env bash
clear
echo '📊 Demo Logs'
echo 'Logs will appear here as the demo runs...'
echo
if [[ -f "$KEMO_LOG_FILE" ]]; then
    tail -f "$KEMO_LOG_FILE"
else
    echo "Log file not found: $KEMO_LOG_FILE"
    while true; do sleep 1000; done
fi
LOG_SCRIPT_EOF
chmod +x "/tmp/kemo-log-pane-$session_name.sh"

# Set up Kubernetes status pane (bottom right)
cat > "/tmp/kemo-k8s-status-pane-$session_name.sh" << 'K8S_STATUS_SCRIPT_EOF'
#!/usr/bin/env bash
clear
gum style --foreground cyan --bold '📊 Kubernetes Status'
watch --interval 2 --no-title kubectl get pods,svc,deploy,events -n $KEMO_NS 2>/dev/null || echo 'No resources found'
K8S_STATUS_SCRIPT_EOF
chmod +x "/tmp/kemo-k8s-status-pane-$session_name.sh"

# Set up main execution pane (bottom left)
cat > "/tmp/kemo-main-pane-$session_name.sh" << 'MAIN_SCRIPT_EOF'
#!/usr/bin/env bash
clear
gum style --foreground green --bold '🧪 Kemo Demo TUI'
gum style --foreground cyan "Demo: $KEMO_DEMO - $KEMO_VARIANT"
gum style --foreground yellow "Step: $KEMO_STEP"
echo
gum style --foreground magenta 'Press Ctrl-k ? for hotkeys help'
echo

# Execute the demo step with progress
gum spin --spinner monkey --title 'Executing step...' -- sleep 1

# Run the actual command and log it
command_str="$*"
if $command_str 2>&1 | tee -a "$KEMO_LOG_FILE"; then
    echo
    gum style --foreground green "✅ Step \"$KEMO_STEP\" completed"
    echo
else
    echo
    gum style --foreground red "❌ Step \"$KEMO_STEP\" failed"
    echo
fi

# Keep the shell open for interaction
exec bash
MAIN_SCRIPT_EOF
chmod +x "/tmp/kemo-main-pane-$session_name.sh"

# Set up metadata viewing pane (bottom left)
cat > "/tmp/kemo-metadata-pane-$session_name.sh" << 'METADATA_SCRIPT_EOF'
#!/usr/bin/env bash
clear
gum style --foreground green --bold 'TODO METADATA GOES HERE'
while true; do sleep 1000; done

METADATA_SCRIPT_EOF
chmod +x "/tmp/kemo-metadata-pane-$session_name.sh"

# Start processes in panes using respawn-pane
tmux_cmd respawn-pane -k -t "$session_name:0.0" "/tmp/kemo-main-pane-$session_name.sh"
tmux_cmd respawn-pane -k -t "$session_name:0.1" "/tmp/kemo-metadata-pane-$session_name.sh"
tmux_cmd respawn-pane -k -t "$session_name:0.2" "/tmp/kemo-log-pane-$session_name.sh"
tmux_cmd respawn-pane -k -t "$session_name:0.3" "/tmp/kemo-k8s-status-pane-$session_name.sh"

# Mark main pane as active
tmux_cmd select-pane -t "$session_name:0.0"

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
current_time=$(date +"%Y-%m-%d %H:%M:%S")
log_clean "✅ Step \"$step\" session ended at \"$current_time\""

# Remove temporary scripts
rm -f "/tmp/kemo-hotkeys-$session_name.sh"
rm -f "/tmp/kemo-log-pane-$session_name.sh"
rm -f "/tmp/kemo-k8s-status-pane-$session_name.sh"
rm -f "/tmp/kemo-main-pane-$session_name.sh"
rm -f "/tmp/kemo-metadata-pane-$session_name.sh"