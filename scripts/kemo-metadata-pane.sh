#!/usr/bin/env bash
# Kemo Demo Metadata Viewing Pane

# Check if required environment variables are set
: "${KEMO_DEMO:?Environment variable KEMO_DEMO must be set}"
: "${KEMO_VARIANT:?Environment variable KEMO_VARIANT must be set}"

clear
metadata_path="demos/$KEMO_DEMO/$KEMO_VARIANT/metadata.yaml"

if [[ -f "$metadata_path" ]]; then
    gum style --foreground cyan --bold "📘 Demo Metadata: $KEMO_DEMO/$KEMO_VARIANT"
    echo
    
    # Display metadata in a formatted way
    if command -v yq >/dev/null 2>&1; then
        yq e '.' "$metadata_path" | gum pager --soft-wrap
    else
        cat "$metadata_path" | gum pager --soft-wrap
    fi
else
    gum style --foreground red "❌ Metadata file not found: $metadata_path"
    gum style --foreground yellow "This pane shows demo metadata when available"
    while true; do sleep 1000; done
fi