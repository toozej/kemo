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

# Get the script directory for resolving relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Set up remaining environment variables
export KEMO_DEMO="$demo"
export KEMO_VARIANT="$variant"
export KEMO_STEP="$step"
export KEMO_LOG_FILE="$log_file"
export KEMO_NS="$demo-$variant"

# Detect provider if not already set (orbstack vs minikube)
if [[ -z "${KEMO_PROVIDER:-}" ]]; then
  current_context="$(kubectl config current-context 2>/dev/null || echo "")"
  if [[ "$current_context" == "orbstack" ]]; then
    export KEMO_PROVIDER="orbstack"
  else
    export KEMO_PROVIDER="minikube"
  fi
fi

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
KEMO_TMUX_CONF="${KEMO_TMUX_CONF:-$PROJECT_ROOT/kemo-tmux.conf}"
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
tmux_cmd set-environment -t "$session_name" KEMO_PROVIDER "${KEMO_PROVIDER}"
tmux_cmd set-environment -t "$session_name" KEMO_SESSION "$session_name"
tmux_cmd set-environment -t "$session_name" SCRIPT_DIR "$SCRIPT_DIR"
tmux_cmd set-environment -t "$session_name" PROJECT_ROOT "$PROJECT_ROOT"

# Initialize the demo stepper
"$SCRIPT_DIR/demo-stepper.sh" init

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

# Start processes in panes using respawn-pane with reusable scripts
tmux_cmd respawn-pane -k -t "$session_name:0.0" "$SCRIPT_DIR/kemo-main-pane.sh $*"
tmux_cmd respawn-pane -k -t "$session_name:0.1" "$SCRIPT_DIR/kemo-metadata-pane.sh"
tmux_cmd respawn-pane -k -t "$session_name:0.2" "$SCRIPT_DIR/kemo-log-pane.sh"
tmux_cmd respawn-pane -k -t "$session_name:0.3" "$SCRIPT_DIR/kemo-k8s-status-pane.sh"

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
rm -f demos/$demo/$variant/.logs/*.tmp
