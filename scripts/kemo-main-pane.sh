#!/usr/bin/env bash
# Kemo Demo Main Execution Pane

# Check if required environment variables are set
: "${KEMO_DEMO:?Environment variable KEMO_DEMO must be set}"
: "${KEMO_VARIANT:?Environment variable KEMO_VARIANT must be set}"
: "${KEMO_STEP:?Environment variable KEMO_STEP must be set}"
: "${KEMO_LOG_FILE:?Environment variable KEMO_LOG_FILE must be set}"

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
if "$@" 2>&1 | tee -a "$KEMO_LOG_FILE"; then
    echo
    gum style --foreground green "✅ Step \"$KEMO_STEP\" completed"
    echo
else
    echo
    gum style --foreground red "❌ Step \"$KEMO_STEP\" failed"
    echo
fi

# Keep the shell open for interaction
exec $SHELL