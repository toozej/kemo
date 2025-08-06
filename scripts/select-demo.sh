#!/usr/bin/env bash

demo_root="demos"
debug_enabled="false"

# Get the script directory for resolving relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse optional flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      debug_enabled="true"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--debug]"
      exit 1
      ;;
  esac
done

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
  if [[ ! -f "$metadata" ]]; then
    gum style --foreground red "❌ Metadata file not found: $metadata"
    continue
  fi

  dir=$(dirname "$metadata")
  relpath="${dir#$demo_root/}"
  demo="${relpath%/*}"
  variant="${relpath##*/}"

  if [[ "$debug_enabled" == "true" ]]; then
    echo "[DEBUG] Processing metadata: $metadata"
    echo "[DEBUG] Processing demo: $demo, variant: $variant"
  fi

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

  label="$(gum style --foreground cyan "$emoji $name") $(gum style --foreground yellow "$desc") $(gum style --foreground magenta "📂 $demo/$variant 🏷 $tags")"
  full_key="$demo::$variant::$metadata"
  choices+=("$label|$full_key")
  ((demo_count++))

  if [[ "$debug_enabled" == "true" ]]; then
    echo "[DEBUG] filter_tag: $filter_tag"
    echo "[DEBUG] tag_match: $tag_match"
    echo "[DEBUG] full_key: $full_key"
    echo "[DEBUG] label: $label"
    echo "[DEBUG] choices: ${choices[*]}"
    echo "[DEBUG] demo_count: $demo_count"
    echo "[DEBUG] metadata: $metadata"
    echo "---"
  fi
done < <(find "$demo_root" -mindepth 3 -maxdepth 3 -name metadata.yaml -print0 | sort -z)

if [[ "${#choices[@]}" -eq 0 ]]; then
  gum style --foreground yellow "😕 No demos found matching tag: '$filter_tag'"
  exit 1
fi

gum style --foreground green "Found $demo_count demos"
echo

# 3. Select Demo Variant
echo -e "📦 Select a demo to run:"
selected_block=$(printf "%s\n" "${choices[@]}" | cut -d '|' -f1 | gum choose --height 20 --header "👇 Choose a demo variant")

if [[ -z "$selected_block" ]]; then
  gum style --foreground red "🛑 No demo selected. Exiting."
  exit 1
fi

selected_key=$(printf "%s\n" "${choices[@]}" | grep -F "$selected_block" | cut -d '|' -f2)
demo="${selected_key%%::*}"
version="${selected_key#*::}"
version="${version%%::*}"
metadata_path="${selected_key##*::}"

gum style --foreground green "Selected: $demo/$version"
echo

# 4. Show Metadata using reusable script
export KEMO_DEMO="$demo"
export KEMO_VARIANT="$version"
"$SCRIPT_DIR/kemo-metadata-pane.sh"

# 5. Pre-flight checks
echo "🔍 Running pre-flight checks..."
just health-check
echo

# 6. Advanced options
advanced_options=$(gum choose --header "🛠️  Additional options (optional)" \
  "Run normally" \
  "Dry run (show commands only)" \
  "Skip cleanup on exit" \
  "Custom namespace")

case "$advanced_options" in
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
$(if [[ -n "${KEMO_NAMESPACE:-}" ]]; then echo "📂 Namespace: $KEMO_NAMESPACE"; fi)
"

if gum confirm "🚀 Start the demo?"; then
  gum style --foreground green --bold "🎬 Starting demo ..."
  echo

  # Run the demo
  just run-demo "$demo" "$version"
else
  gum style --foreground red "🛑 Demo canceled."
  echo
  
  # Ask if they want to select a different demo
  if gum confirm "Would you like to select a different demo?"; then
    exec "$0" "$@"
  fi
fi