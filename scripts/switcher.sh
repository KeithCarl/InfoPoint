#!/bin/bash

# InfoPoint URL Switcher Script with Timeout Support
# This script cycles through URLs with individual timeout settings

CONFIG_FILE="/opt/infopoint/config/urls.json"
LOG_FILE="/opt/infopoint/logs/switcher.log"
CHROMIUM_PID_FILE="/tmp/infopoint_chromium.pid"

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if Chromium is running
is_chromium_running() {
    if [[ -f "$CHROMIUM_PID_FILE" ]]; then
        local pid=$(cat "$CHROMIUM_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$CHROMIUM_PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Function to start Chromium
start_chromium() {
    local url="$1"
    log "Starting Chromium with URL: $url"
    
    # Kill any existing Chromium processes
    pkill -f "chromium-browser" 2>/dev/null
    sleep 2
    
    # Start Chromium in kiosk mode
    chromium-browser \
        --kiosk \
        --noerrdialogs \
        --disable-infobars \
        --disable-session-crashed-bubble \
        --disable-component-update \
        --disable-background-timer-throttling \
        --disable-backgrounding-occluded-windows \
        --disable-renderer-backgrounding \
        --disable-features=TranslateUI \
        --disable-web-security \
        --disable-features=VizDisplayCompositor \
        --start-maximized \
        --no-first-run \
        --fast \
        --fast-start \
        --disable-default-apps \
        --disable-popup-blocking \
        --disable-prompt-on-repost \
        --no-default-browser-check \
        --no-pings \
        --media-cache-size=1 \
        --disk-cache-size=1 \
        --aggressive-cache-discard \
        --memory-pressure-off \
        --max_old_space_size=100 \
        --renderer-process-limit=1 \
        --max-gum-fps=30 \
        --disable-background-mode \
        --disable-extensions \
        --disable-plugins \
        --disable-java \
        --disable-bundled-ppapi-flash \
        --autoplay-policy=no-user-gesture-required \
        "$url" &
    
    local chromium_pid=$!
    echo "$chromium_pid" > "$CHROMIUM_PID_FILE"
    log "Chromium started with PID: $chromium_pid"
}

# Function to navigate to URL
navigate_to_url() {
    local url="$1"
    log "Navigating to: $url"
    
    if is_chromium_running; then
        # Use wmctrl to focus window and send navigation command
        wmctrl -a "Chromium" 2>/dev/null
        sleep 1
        
        # Send Ctrl+L to focus address bar, then type URL and press Enter
        wtype $'\\c\\l'
        sleep 0.5
        wtype --clearmodifiers "$url"
        sleep 0.5
        wtype $'\\r'
    else
        start_chromium "$url"
    fi
}

# Function to parse JSON config
parse_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR: Config file not found: $CONFIG_FILE"
        return 1
    fi
    
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log "ERROR: Invalid JSON in config file"
        return 1
    fi
    
    return 0
}

# Function to get URL count
get_url_count() {
    jq '.urls | length' "$CONFIG_FILE" 2>/dev/null || echo "0"
}

# Function to get URL by index
get_url() {
    local index="$1"
    jq -r ".urls[$index].url" "$CONFIG_FILE" 2>/dev/null || echo ""
}

# Function to get timeout by index
get_timeout() {
    local index="$1"
    local timeout=$(jq -r ".urls[$index].timeout" "$CONFIG_FILE" 2>/dev/null)
    local global_timeout=$(jq -r ".globalTimeout" "$CONFIG_FILE" 2>/dev/null)
    
    # Use URL-specific timeout if available, otherwise use global timeout
    if [[ "$timeout" != "null" && "$timeout" != "" ]]; then
        echo "$timeout"
    elif [[ "$global_timeout" != "null" && "$global_timeout" != "" ]]; then
        echo "$global_timeout"
    else
        echo "30000"  # Default fallback
    fi
}

# Function to get transition delay
get_transition_delay() {
    local delay=$(jq -r ".transitionDelay" "$CONFIG_FILE" 2>/dev/null)
    if [[ "$delay" != "null" && "$delay" != "" ]]; then
        echo "$delay"
    else
        echo "2000"  # Default fallback
    fi
}

# Function to get display name
get_display_name() {
    local index="$1"
    jq -r ".urls[$index].name" "$CONFIG_FILE" 2>/dev/null || echo ""
}

# Function to wait for specified time with progress indication
wait_with_progress() {
    local timeout_ms="$1"
    local display_name="$2"
    local timeout_sec=$((timeout_ms / 1000))
    
    log "Displaying '$display_name' for ${timeout_sec} seconds (${timeout_ms}ms)"
    
    # Show progress every 10 seconds for long timeouts
    if [[ $timeout_sec -gt 10 ]]; then
        local progress_interval=10
        local elapsed=0
        
        while [[ $elapsed -lt $timeout_sec ]]; do
            local remaining=$((timeout_sec - elapsed))
            if [[ $remaining -le $progress_interval ]]; then
                sleep "$remaining"
                break
            else
                sleep $progress_interval
                elapsed=$((elapsed + progress_interval))
                log "Still displaying '$display_name' - ${remaining} seconds remaining"
            fi
        done
    else
        sleep "$timeout_sec"
    fi
}

# Main switching loop
main() {
    log "InfoPoint URL Switcher started"
    
    # Wait for network to be available
    while ! ping -c 1 google.com &> /dev/null; do
        log "Waiting for network connection..."
        sleep 5
    done
    
    log "Network connection established"
    
    # Main loop
    local current_index=0
    
    while true; do
        # Parse and validate config
        if ! parse_config; then
            log "Config parsing failed, retrying in 10 seconds..."
            sleep 10
            continue
        fi
        
        local url_count=$(get_url_count)
        
        if [[ $url_count -eq 0 ]]; then
            log "No URLs configured, waiting 30 seconds..."
            sleep 30
            continue
        fi
        
        # Reset index if it exceeds available URLs
        if [[ $current_index -ge $url_count ]]; then
            current_index=0
        fi
        
        # Get current URL and its settings
        local current_url=$(get_url "$current_index")
        local timeout=$(get_timeout "$current_index")
        local display_name=$(get_display_name "$current_index")
        local transition_delay=$(get_transition_delay)
        
        if [[ -z "$current_url" ]]; then
            log "ERROR: Could not get URL at index $current_index"
            current_index=$((current_index + 1))
            continue
        fi
        
        # Navigate to URL
        navigate_to_url "$current_url"
        
        # Wait for the specified timeout
        wait_with_progress "$timeout" "$display_name"
        
        # Add transition delay if configured
        if [[ $transition_delay -gt 0 ]]; then
            local delay_sec=$((transition_delay / 1000))
            log "Transition delay: ${delay_sec} seconds"
            sleep "$delay_sec"
        fi
        
        # Move to next URL
        current_index=$((current_index + 1))
    done
}

# Signal handlers for graceful shutdown
cleanup() {
    log "InfoPoint URL Switcher shutting down..."
    
    if [[ -f "$CHROMIUM_PID_FILE" ]]; then
        local pid=$(cat "$CHROMIUM_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            log "Stopping Chromium (PID: $pid)"
            kill "$pid" 2>/dev/null
        fi
        rm -f "$CHROMIUM_PID_FILE"
    fi
    
    # Kill any remaining Chromium processes
    pkill -f "chromium-browser" 2>/dev/null
    
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Ensure only one instance runs
LOCK_FILE="/tmp/infopoint_switcher.lock"
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log "Another instance of InfoPoint switcher is already running"
    exit 1
fi

# Start the main function
main
