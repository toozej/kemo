#!/usr/bin/env bash
# Kemo Demo Log Pane

# Check if required environment variables are set
: "${KEMO_LOG_FILE:?Environment variable KEMO_LOG_FILE must be set}"

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