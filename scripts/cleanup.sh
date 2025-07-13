#!/bin/bash

# InfoPoint Cleanup Script
# Removes InfoPoint installation and restores system

set -e

# Configuration
INFOPOINT_DIR="/opt/infopoint"
SERVICE_NAME="infopoint"
USER="pi"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
    exit 1
fi

# Function to stop and disable services
stop_services() {
    log "Stopping InfoPoint services..."
    
    # Stop services
    systemctl stop "${SERVICE_NAME}.service" 2>/dev/null || true
    systemctl stop "${SERVICE_NAME}-kiosk.service" 2>/dev/null || true
    
    # Disable services
    systemctl disable "${SERVICE_NAME}.service" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}-kiosk.service" 2>/dev/null || true
    
    success "Services stopped and disabled"
}

# Function to remove service files
remove_service_files() {
    log "Removing service files..."
    
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    rm -f "/etc/systemd/system/${SERVICE_NAME}-kiosk.service"
    
    systemctl daemon-reload
    
    success "Service files removed"
}

# Function to remove autostart files
remove_autostart_files() {
    log "Removing autostart files..."
    
    rm -f "/home/$USER/.config/autostart/infopoint.desktop"
    
    success "Autostart files removed"
}

# Function to backup configuration
backup_configuration() {
    if [[ -f "$INFOPOINT_DIR/config/urls.json" ]]; then
        log "Backing up configuration..."
        
        local backup_dir="/home/$USER/infopoint_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        
        cp "$INFOPOINT_DIR/config/urls.json" "$backup_dir/"
        cp -r "$INFOPOINT_DIR/logs" "$backup_dir/" 2>/dev/null || true
        
        chown -R "$USER:$USER" "$backup_dir"
        
        success "Configuration backed up to: $backup_dir"
        echo "  You can restore this configuration when reinstalling InfoPoint"
    fi
}

# Function to kill running processes
kill_processes() {
    log "Stopping InfoPoint processes..."
    
    # Kill Chromium processes
    pkill -f "chromium-browser" 2>/dev/null || true
    
    # Kill Node.js processes related to InfoPoint
    pkill -f "node.*index.js" 2>/dev/null || true
    
    # Kill switcher processes
    pkill -f "switcher.sh" 2>/dev/null || true
    
    # Remove PID files
    rm -f /tmp/infopoint_*.pid
    rm -f /tmp/infopoint_*.lock
    
    success "Processes stopped"
}

# Function to remove InfoPoint directory
remove_directory() {
    log "Removing InfoPoint directory..."
    
    if [[ -d "$INFOPOINT_DIR" ]]; then
        rm -rf "$INFOPOINT_DIR"
        success "InfoPoint directory removed"
    else
        warn "InfoPoint directory not found"
    fi
}

# Function to restore boot behavior
restore_boot_behavior() {
    log "Restoring boot behavior..."
    
    # Reset to desktop auto-login (default)
    raspi-config nonint do_boot_behaviour B4
    
    success "Boot behavior restored"
}

# Function to clean up temporary files
cleanup_temp_files() {
    log "Cleaning up temporary files..."
    
    # Remove lock files
    rm -f /tmp/infopoint_*
    
    # Remove any remaining InfoPoint-related files in /tmp
    find /tmp -name "*infopoint*" -type f -delete 2>/dev/null || true
    
    success "Temporary files cleaned up"
}

# Function to ask for package removal
ask_remove_packages() {
    echo
    warn "InfoPoint installed several system packages during setup."
    warn "These packages were NOT removed to avoid breaking other applications:"
    echo
    echo "  - chromium-browser"
    echo "  - wmctrl"
    echo "  - wtype"
    echo "  - jq"
    echo "  - git"
    echo "  - curl"
    echo "  - unzip"
    echo "  - xdotool"
    echo "  - x11-xserver-utils"
    echo "  - matchbox-window-manager"
    echo "  - xautomation"
    echo "  - unclutter-xfixes"
    echo "  - nodejs"
    echo
    echo "If you want to remove these packages, you can do so manually using:"
    echo "  sudo apt-get remove --purge [package-name]"
    echo
}

# Function to display completion message
display_completion() {
    echo
    success "============================================"
    success "InfoPoint removal completed successfully!"
    success "============================================"
    echo
    success "What was removed:"
    success "  - InfoPoint application files"
    success "  - System services"
    success "  - Autostart configuration"
    success "  - Temporary files"
    echo
    success "What was preserved:"
    success "  - Configuration backup (if any)"
    success "  - System packages"
    success "  - User data"
    echo
    success "To complete the cleanup, you may want to:"
    success "  1. Reboot the system: sudo reboot"
    success "  2. Review backed up configuration files"
    success "  3. Manually remove unused packages if desired"
    echo
}

# Main cleanup function
main() {
    log "Starting InfoPoint removal..."
    
    # Confirm removal
    echo -e "${YELLOW}This will remove InfoPoint from your system.${NC}"
    echo -e "${YELLOW}Configuration will be backed up before removal.${NC}"
    echo
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Removal cancelled by user"
        exit 0
    fi
    
    # Backup configuration before removal
    backup_configuration
    
    # Stop all InfoPoint processes
    kill_processes
    
    # Remove services
    stop_services
    remove_service_files
    
    # Remove autostart files
    remove_autostart_files
    
    # Remove application directory
    remove_directory
    
    # Restore system configuration
    restore_boot_behavior
    
    # Clean up temporary files
    cleanup_temp_files
    
    # Show package removal information
    ask_remove_packages
    
    # Display completion message
    display_completion
    
    success "InfoPoint removal completed!"
}

# Handle script interruption
trap 'error "Removal interrupted"; exit 1' INT TERM

# Run main cleanup
main "$@"
