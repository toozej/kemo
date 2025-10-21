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
    --dry-run)
      export KEMO_DRY_RUN=true
      shift
      ;;
    --skip-cleanup)
      export KEMO_SKIP_CLEANUP=true
      shift
      ;;
    --namespace)
      if [[ -n "$2" && ! "$2" =~ ^-- ]]; then
        export KEMO_NAMESPACE="$2"
        shift 2
      else
        echo "Error: --namespace requires a value"
        exit 1
      fi
      ;;
    --quick)
      export KEMO_QUICK_MODE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --debug          Enable debug output"
      echo "  --dry-run        Show commands without executing"
      echo "  --skip-cleanup   Skip cleanup on exit"
      echo "  --namespace NS   Use custom namespace"
      echo "  --quick          Skip confirmations and metadata preview"
      echo "  --help, -h       Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

if [[ ! -d "$demo_root" ]]; then
  gum style --foreground red "❌ No demo directory found."
  exit 1
fi

# Welcome message (skip in quick mode)
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
  gum style --foreground cyan --bold "🧪 Welcome to Kemo Demo Selector"
  echo
fi

# 1. Tag Filter Selection with spinner (skip in quick mode)
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
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
else
  # Quick mode: use "All" filter
  filter_tag="__ALL__"
fi

# 2. Build Demo List with progress (skip spinner in quick mode)
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
  gum spin --spinner globe --title "📦 Building demo list..." -- sleep 1
fi

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

if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
  gum style --foreground green "Found $demo_count demos"
  echo
fi

# 3. Select Demo Variant
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
  echo -e "📦 Select a demo to run:"
  selected_block=$(printf "%s\n" "${choices[@]}" | cut -d '|' -f1 | gum choose --height 20 --header "👇 Choose a demo variant")
else
  # Quick mode: auto-select first demo if only one, otherwise exit
  if [[ "${#choices[@]}" -eq 1 ]]; then
    selected_block=$(printf "%s\n" "${choices[0]}" | cut -d '|' -f1)
  else
    gum style --foreground yellow "⚠️  Quick mode requires exactly one demo. Found ${#choices[@]}. Use interactive mode."
    exit 1
  fi
fi

if [[ -z "$selected_block" ]]; then
  gum style --foreground red "🛑 No demo selected. Exiting."
  exit 1
fi

selected_key=$(printf "%s\n" "${choices[@]}" | grep -F "$selected_block" | cut -d '|' -f2)
demo="${selected_key%%::*}"
version="${selected_key#*::}"
version="${version%%::*}"
metadata_path="${selected_key##*::}"

if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
  gum style --foreground green "Selected: $demo/$version"
  echo
fi

# 4. Show Metadata using reusable script (skip in quick mode)
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
  export KEMO_DEMO="$demo"
  export KEMO_VARIANT="$version"
  "$SCRIPT_DIR/kemo-metadata-pane.sh"
fi

# 5. Pre-flight checks (skip in quick mode)
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
  echo "🔍 Running pre-flight checks..."
  just health-check
  echo
fi

# 6. Advanced options (skip in quick mode)
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
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
fi

# 7. Final confirmation with summary (skip in quick mode)
if [[ "${KEMO_QUICK_MODE:-false}" != "true" ]]; then
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
else
  # Quick mode: run immediately
  gum style --foreground green --bold "🎬 Starting demo: $demo/$version"
  echo
  just run-demo "$demo" "$version"
fi