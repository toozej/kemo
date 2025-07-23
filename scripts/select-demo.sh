#!/usr/bin/env bash
set -euo pipefail

demo_root="demos"
log_enabled="false"
debug_enabled="false"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --log)
      log_enabled="true"
      shift
      ;;
    --debug)
      debug_enabled="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--log] [--debug]"
      exit 1
      ;;
  esac
done

echo "Debug mode: $debug_enabled"
echo "Logging enabled: $log_enabled"

if [[ ! -d "$demo_root" ]]; then
  gum style --foreground red "❌ No demo directory found."
  exit 1
fi

# Welcome message
gum style --foreground cyan --bold "🧪 Welcome to Kemo Demo Selector"
echo

# 1. Tag Filter Selection with spinner
gum spin --spinner dot --title "🔍 Scanning for demo tags..." -- sleep 1

echo "🎯 Pick a tag to filter demos (or 'All'):"
tags=$(find "$demo_root" -name metadata.yaml -exec yq e '.tags // [] | .[]' {} \; | sort -u)

if [[ -z "$tags" ]]; then
  gum style --foreground yellow "⚠️  No tags found in demos"
  selected_tag="All"
else
  selected_tag=$(printf "All\n%s\n" "$tags" | gum filter --prompt "🔖 Tag > " --placeholder "Start typing a tag...")
fi

if [[ -z "$selected_tag" ]]; then
  gum style --foreground red "🛑 No tag selected. Exiting."
  exit 1
fi

[[ "$selected_tag" == "All" ]] && filter_tag="__ALL__" || filter_tag="$selected_tag"

gum style --foreground green "Selected filter: $selected_tag"
echo

# 2. Build Demo List with progress
gum spin --spinner globe --title "📦 Building demo list..." -- sleep 1

choices=()
demo_count=0

while IFS= read -r -d '' metadata; do
  dir=$(dirname "$metadata")
  relpath="${dir#$demo_root/}"
  demo="${relpath%/*}"
  variant="${relpath##*/}"

  tag_match="true"
  if [[ "$filter_tag" != "__ALL__" ]]; then
    if ! yq e '.tags // [] | .[]' "$metadata" | grep -Fxq "$filter_tag"; then
      tag_match="false"
      continue
    fi
  fi

  name=$(yq e '.name' "$metadata")
  desc=$(yq e '.description' "$metadata" | head -n 1)
  tags=$(yq e '.tags // [] | join(", ")' "$metadata")
  emoji="❌"
  [[ "$variant" == "good" ]] && emoji="✅"

  label="$(gum style --foreground cyan "$emoji $name")\n  $(gum style --foreground yellow "$desc")\n  $(gum style --foreground magenta "📂 $demo/$variant  🏷 $tags")"
  full_key="$demo::$variant::$metadata"
  choices+=("$label:::$full_key")
  ((demo_count++))

  if [[ "$debug_enabled" == "true" ]]; then
    echo "[DEBUG] label: $label"
    echo "[DEBUG] tags: $tags"
    echo "[DEBUG] filter_tag: $filter_tag"
    echo "[DEBUG] tag_match: $tag_match"
    echo "[DEBUG] metadata: $metadata"
    echo "---"
  fi
done < <(find "$demo_root" -mindepth 3 -maxdepth 3 -name metadata.yaml -print0 | sort -z)

if [[ ${#choices[@]} -eq 0 ]]; then
  gum style --foreground yellow "😕 No demos found matching tag: '$filter_tag'"
  exit 1
fi

gum style --foreground green "Found $demo_count demos"
echo

# 3. Select Demo Variant
echo -e "📦 Select a demo to run:"
selected_block=$(printf "%s\n" "${choices[@]}" | cut -d ':::' -f1 | gum choose --height 20 --header "👇 Choose a demo variant")

if [[ -z "$selected_block" ]]; then
  gum style --foreground red "🛑 No demo selected. Exiting."
  exit 1
fi

selected_key=$(printf "%s\n" "${choices[@]}" | grep -F "$selected_block" | cut -d ':::' -f2)
demo="${selected_key%%::*}"
version="${selected_key#*::}"
version="${version%%::*}"
metadata_path="${selected_key##*::}"

gum style --foreground green "Selected: $demo/$version"
echo

# 4. Show Metadata in Pager
gum spin --spinner dot --title "📖 Loading demo metadata..." -- sleep 0.5

echo -e "📘 Demo Info (Press q to exit)\n" > /tmp/demo-meta.md
echo -e "**🧪 Demo:** \`$demo/$version\`\n" >> /tmp/demo-meta.md
yq e '.' "$metadata_path" | sed 's/^/    /' >> /tmp/demo-meta.md
gum pager < /tmp/demo-meta.md

# 5. Pre-flight checks
echo "🔍 Running pre-flight checks..."

# Check if kubectl is available
if ! command -v kubectl >/dev/null; then
  gum style --foreground red "❌ kubectl not found"
  if ! gum confirm "Continue anyway?"; then
    exit 1
  fi
else
  gum style --foreground green "✅ kubectl available"
fi

# Check if cluster is accessible
if kubectl cluster-info >/dev/null 2>&1; then
  gum style --foreground green "✅ Kubernetes cluster accessible"
else
  gum style --foreground yellow "⚠️  Kubernetes cluster not accessible"
  if ! gum confirm "Continue anyway?"; then
    exit 1
  fi
fi

# Check if tmux is available for TUI
if ! command -v tmux >/dev/null; then
  gum style --foreground red "❌ tmux not found - TUI will not be available"
  if ! gum confirm "Continue without TUI?"; then
    exit 1
  fi
else
  gum style --foreground green "✅ tmux available - TUI enabled"
fi

echo

# 6. Advanced options
advanced_options=$(gum choose --header "🛠️  Additional options (optional)" \
  "Run normally" \
  "Enable verbose logging" \
  "Dry run (show commands only)" \
  "Skip cleanup on exit" \
  "Custom namespace")

case "$advanced_options" in
  "Enable verbose logging")
    export KEMO_VERBOSE=true
    gum style --foreground yellow "📝 Verbose logging enabled"
    ;;
  "Dry run (show commands only)")
    export KEMO_DRY_RUN=true
    gum style --foreground cyan "🔍 Dry run mode enabled"
    ;;
  "Skip cleanup on exit")
    export KEMO_SKIP_CLEANUP=true
    gum style --foreground yellow "⚠️  Cleanup will be skipped"
    ;;
  "Custom namespace")
    custom_namespace=$(gum input --placeholder "Enter namespace name" --prompt "Namespace > ")
    if [[ -n "$custom_namespace" ]]; then
      export KEMO_NAMESPACE="$custom_namespace"
      gum style --foreground blue "📂 Using namespace: $custom_namespace"
    fi
    ;;
esac

echo

# 7. Final confirmation with summary
gum style --foreground cyan --border normal --margin "1 2" --padding "1 2" "
🎬 Ready to run demo

📦 Demo: $demo
🔧 Variant: $version  
🏷️  Tags: $(yq e '.tags // [] | join(", ")' "$metadata_path")
$(if [[ "$log_enabled" == "true" ]]; then echo "📝 Logging: Enabled"; fi)
$(if [[ -n "${KEMO_NAMESPACE:-}" ]]; then echo "📂 Namespace: $KEMO_NAMESPACE"; fi)
"

if gum confirm "🚀 Start the demo?"; then
  # Show countdown
  gum style --foreground green --bold "🎬 Starting demo in..."
  for i in {3..1}; do
    gum style --foreground yellow "$i..."
    sleep 1
  done
  gum style --foreground green "🚀 GO!"
  echo

  if [[ "$log_enabled" == "true" ]]; then
    timestamp=$(date +"%Y%m%d_%H%M%S")
    log_dir="logs/$demo/$version"
    mkdir -p "$log_dir"
    log_file="$log_dir/demo-$timestamp.log"
    gum style --foreground cyan "📝 Logging output to: $log_file"
    
    # Progress bar while setting up logging
    gum progress --from 0 --to 100 --delay 50ms --title "Setting up logging..." > /dev/null &
    sleep 1
    
    just run-demo "$demo" "$version" 2>&1 | tee "$log_file"
  else
    just run-demo "$demo" "$version"
  fi
else
  gum style --foreground red "🛑 Demo canceled."
  echo
  
  # Ask if they want to select a different demo
  if gum confirm "Would you like to select a different demo?"; then
    exec "$0" "$@"
  fi
fi

# Cleanup temp files
rm -f /tmp/demo-meta.md