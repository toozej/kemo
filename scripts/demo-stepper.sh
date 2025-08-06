#!/usr/bin/env bash
# Kemo Demo Stepper - Execute demo run.sh scripts step-by-step

# Check if required environment variables are set
: "${KEMO_DEMO:?Environment variable KEMO_DEMO must be set}"
: "${KEMO_VARIANT:?Environment variable KEMO_VARIANT must be set}" 
: "${KEMO_NS:?Environment variable KEMO_NS must be set}"
: "${KEMO_LOG_FILE:?Environment variable KEMO_LOG_FILE must be set}"

DEMO_DIR="demos/$KEMO_DEMO/$KEMO_VARIANT"
RUN_SCRIPT="$DEMO_DIR/run.sh"
STATE_DIR="$DEMO_DIR/.logs"
STATE_FILE="$STATE_DIR/stepper-state.tmp"
COMMANDS_FILE="$STATE_DIR/stepper-commands.tmp"

# Initialize stepper state
init_stepper() {
    mkdir -p "$STATE_DIR"
    
    if [[ ! -f "$RUN_SCRIPT" ]]; then
        gum style --foreground yellow "⚠️  No run.sh script found for this demo"
        echo "0" > "$STATE_FILE"
        echo "" > "$COMMANDS_FILE"
        return 0
    fi
    
    # Parse the run.sh script into executable sections
    # Each section is separated by blank lines or comments starting with #
    local section=""
    local section_num=0
    
    > "$COMMANDS_FILE"  # Clear commands file
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip shebang line
        if [[ "$line" =~ ^#! ]]; then
            continue
        fi
        
        # If line is empty or a comment-only line, end current section
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]*#[[:space:]]*$ ]]; then
            if [[ -n "$section" ]]; then
                echo "SECTION_${section_num}:" >> "$COMMANDS_FILE"
                echo "$section" >> "$COMMANDS_FILE"
                echo "---" >> "$COMMANDS_FILE"
                ((section_num++))
                section=""
            fi
            continue
        fi
        
        # Add line to current section
        if [[ -n "$section" ]]; then
            section="$section"$'\n'"$line"
        else
            section="$line"
        fi
    done < "$RUN_SCRIPT"
    
    # Don't forget the last section if script doesn't end with blank line
    if [[ -n "$section" ]]; then
        echo "SECTION_${section_num}:" >> "$COMMANDS_FILE"
        echo "$section" >> "$COMMANDS_FILE"
        echo "---" >> "$COMMANDS_FILE"
        ((section_num++))
    fi
    
    # Initialize current step to 0
    echo "0" > "$STATE_FILE"
    
    gum style --foreground green "✅ Stepper initialized with $section_num sections"
}

# Get current step number
get_current_step() {
    if [[ -f "$STATE_FILE" ]]; then
        cat "$STATE_FILE"
    else
        echo "0"
    fi
}

# Set current step number
set_current_step() {
    echo "$1" > "$STATE_FILE"
}

# Get total number of steps
get_total_steps() {
    if [[ -f "$COMMANDS_FILE" ]]; then
        grep -c "^SECTION_" "$COMMANDS_FILE" || echo "0"
    else
        echo "0"
    fi
}

# Get command for specific step
get_step_command() {
    local step=$1
    if [[ -f "$COMMANDS_FILE" ]]; then
        awk "/^SECTION_${step}:/{flag=1; next} /^---$/{flag=0} flag" "$COMMANDS_FILE"
    fi
}

# Execute next step
next_step() {
    local current_step=$(get_current_step)
    local total_steps=$(get_total_steps)
    
    if [[ $total_steps -eq 0 ]]; then
        gum style --foreground yellow "⚠️  No steps available to execute"
        return 0
    fi
    
    if [[ $current_step -ge $total_steps ]]; then
        gum style --foreground green "✅ All steps completed!"
        gum style --foreground cyan "Run 'Ctrl-k r' to restart the demo"
        return 0
    fi
    
    local command=$(get_step_command "$current_step")
    
    if [[ -z "$command" ]]; then
        gum style --foreground red "❌ No command found for step $current_step"
        return 1
    fi
    
    # Log the step execution
    echo "[$current_step/$total_steps] Executing step $((current_step + 1)):" >> "$KEMO_LOG_FILE"
    echo "$command" >> "$KEMO_LOG_FILE"
    echo "---" >> "$KEMO_LOG_FILE"
    
    # Display step info
    gum style --foreground cyan "📋 Step $((current_step + 1)) of $total_steps"
    gum style --foreground white "Command:"
    echo "$command" | gum style --foreground yellow --border normal --margin "0 2"
    echo

    gum style --foreground blue "🚀 Executing..."

    # Execute the command in the demo directory context
    if (
        cd "$DEMO_DIR"
        # Use eval to properly handle complex bash constructs
        eval "$command"
    ) 2>&1 | tee -a "$KEMO_LOG_FILE"; then
        gum style --foreground green "✅ Step $((current_step + 1)) completed successfully"
        set_current_step $((current_step + 1))
    else
        gum style --foreground red "❌ Step $((current_step + 1)) failed"
        echo "Step $((current_step + 1)) failed with exit code $?" >> "$KEMO_LOG_FILE"
        set_current_step $((current_step + 1))
    fi

    echo
    if [[ $((current_step + 1)) -lt $total_steps ]]; then
        gum style --foreground cyan "💡 Press 'Ctrl-k n' for next step"
    else
        gum style --foreground green "🎉 Demo completed! Press 'Ctrl-k r' to restart"
    fi
}

# Reset stepper to beginning
reset_stepper() {
    set_current_step 0
    gum style --foreground yellow "🔄 Stepper reset to beginning"
}

# Show stepper status
show_status() {
    local current_step=$(get_current_step)
    local total_steps=$(get_total_steps)
    
    gum style --foreground cyan --bold "📊 Demo Stepper Status"
    echo
    gum style --foreground white "Current Step: $((current_step + 1)) of $total_steps"
    
    if [[ $total_steps -gt 0 ]]; then
        local progress=$((current_step * 100 / total_steps))
        gum style --foreground white "Progress: ${progress}%"
        
        if [[ $current_step -lt $total_steps ]]; then
            echo
            gum style --foreground yellow "Next command:"
            local next_command=$(get_step_command "$current_step")
            echo "$next_command" | gum style --foreground cyan --border normal --margin "0 2"
        fi
    fi
}

# Cleanup stepper state
cleanup_stepper() {
    rm -f "$STATE_FILE" "$COMMANDS_FILE"
    gum style --foreground green "🧹 Stepper state cleaned up"
}

# Main function
main() {
    case "${1:-}" in
        "init")
            init_stepper
            ;;
        "next")
            next_step
            ;;
        "reset")
            reset_stepper
            ;;
        "status")
            show_status
            ;;
        "cleanup")
            cleanup_stepper
            ;;
        *)
            # If no argument provided, initialize and show status
            if [[ ! -f "$STATE_FILE" ]]; then
                init_stepper
            fi
            show_status
            ;;
    esac
}

main "$@"