#!/usr/bin/env bash
# Kemo Demo Main Execution Pane

# Check if required environment variables are set
: "${KEMO_DEMO:?Environment variable KEMO_DEMO must be set}"
: "${KEMO_VARIANT:?Environment variable KEMO_VARIANT must be set}"
: "${KEMO_STEP:?Environment variable KEMO_STEP must be set}"
: "${KEMO_LOG_FILE:?Environment variable KEMO_LOG_FILE must be set}"
: "${SCRIPT_DIR:?Environment variable SCRIPT_DIR must be set}"
: "${PROJECT_ROOT:?Environment variable PROJECT_ROOT must be set}"

clear
gum style --foreground green --bold '🧪 Kemo Demo TUI'
gum style --foreground cyan "Demo: $KEMO_DEMO - $KEMO_VARIANT"
gum style --foreground yellow "Step: $KEMO_STEP"
echo
gum style --foreground magenta 'Press Ctrl-k ? for hotkeys help'
gum style --foreground cyan 'Press Ctrl-k n for next step'
echo

# Show initial stepper status
"$SCRIPT_DIR/demo-stepper.sh" status

# Wait for user to press Ctrl-k n to proceed
gum style --foreground yellow "Ready for manual stepping. Use Ctrl-k n to execute next step."

# Keep the shell open for interaction
exec $SHELL