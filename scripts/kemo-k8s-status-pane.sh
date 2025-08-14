#!/usr/bin/env bash
# Kemo Demo Kubernetes Status Pane

# Check if required environment variables are set
: "${KEMO_NS:?Environment variable KEMO_NS must be set}"

clear
gum style --foreground cyan --bold '📊 Kubernetes Status'
watch --interval 2 --no-title "kubectl get pods,deploy,events -n $KEMO_NS 2>/dev/null || echo 'No resources found'"