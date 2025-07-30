#!/usr/bin/env bash

tmux_cmd() {
  tmux -f "$KEMO_TMUX_CONF" "$@"
}

KEMO_TMUX_CONF="${KEMO_TMUX_CONF:-./kemo-tmux.conf}"

session_name="kemo-test-$(date +%s)"

tmux_cmd new-session -d -s "$session_name" -n "test" -x 120 -y 40

# Wait a moment for session to be fully created
sleep 0.5

# Verify session exists before proceeding
if ! tmux_cmd has-session -t "$session_name" 2>/dev/null; then
  echo "❌ Failed to create tmux session"
  exit 1
fi

tmux_cmd select-window -t "$session_name:0"
tmux_cmd split-window -t "$session_name:0" -h -p 30
# After splitting, pane 0.0 is left, 0.1 is right

# Split left pane (0.0) vertically
tmux_cmd split-window -t "$session_name:0.0" -v -p 15
# After splitting, pane 0.0 is top left, 0.1 is bottom left, 0.2 is right

# Split right pane (0.2) vertically to create 0.3 (bottom right)
tmux_cmd split-window -t "$session_name:0.2" -v -p 50
# After splitting, pane 0.0 is top left, 0.1 is bottom left, pane 0.2 is top right, 0.3 is bottom right

tmux_cmd respawn-pane -k -t "$session_name:0.0" "echo main-pane; sleep 1000"
tmux_cmd respawn-pane -k -t "$session_name:0.1" "echo metadata-pane; sleep 1000"
tmux_cmd respawn-pane -k -t "$session_name:0.2" "echo log-pane; sleep 1000"
tmux_cmd respawn-pane -k -t "$session_name:0.3" "echo k8s-status-pane; sleep 1000"

tmux_cmd attach-session -t "$session_name"
