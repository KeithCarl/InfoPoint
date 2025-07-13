#!/bin/bash

# InfoPoint Setup Script
# One-shot setup for Raspberry Pi kiosk mode with timeout support

set -e

# Configuration
INFOPOINT_DIR="/opt/infopoint"
SERVICE_NAME="infopoint"
USER="pi"
NODEJS_VERSION="18"

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

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    warn "This script is designed for Raspberry Pi, but will attempt to continue"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get IP address
get_ip_address() {
    local ip=$(hostname -I | awk '{print $1}')
    if [[ -z "$ip" ]]; then
        ip=$(ip route get 8.8.8.8 | awk '{print $7; exit}' 2>/dev/null)
    fi
    echo "$ip"
}

# Function to install Node.js
install_nodejs() {
    log "Installing Node.js $NODEJS_VERSION..."
    
    if command_exists node; then
        local current_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$current_version" -ge "$NODEJS_VERSION" ]]; then
            success "Node.js $current_version is already installed"
            return
        fi
    fi
    
    # Install Node.js using NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | bash -
    apt-get install -y nodejs
    
    success "Node.js $(node -v) installed successfully"
}

# Function to install system dependencies
install_dependencies() {
    log "Updating package list..."
    apt-get update
    
    log "Installing system dependencies..."
    apt-get install -y \
        chromium-browser \
        wmctrl \
        wtype \
        jq \
        git \
        curl \
        unzip \
        xdotool \
        x11-xserver-utils \
        matchbox-window-manager \
        xautomation \
        unclutter-xfixes
    
    success "System dependencies installed"
}

# Function to create InfoPoint directory structure
create_directories() {
    log "Creating InfoPoint directory structure..."
    
    mkdir -p "$INFOPOINT_DIR"/{scripts,config,logs,public}
    chown -R "$USER:$USER" "$INFOPOINT_DIR"
    
    success "Directory structure created"
}

# Function to create InfoPoint service files
create_service_files() {
    log "Creating systemd service files..."
    
    # Create InfoPoint dashboard service
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=InfoPoint Dashboard Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$INFOPOINT_DIR
ExecStart=/usr/bin/node index.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=infopoint-dashboard

[Install]
WantedBy=multi-user.target
EOF

    # Create InfoPoint kiosk service
    cat > "/etc/systemd/system/${SERVICE_NAME}-kiosk.service" << EOF
[Unit]
Description=InfoPoint Kiosk Mode
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$INFOPOINT_DIR
Environment=DISPLAY=:0
ExecStart=$INFOPOINT_DIR/scripts/runner.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=infopoint-kiosk

[Install]
WantedBy=graphical-session.target
EOF

    success "Service files created"
}

# Function to create runner script
create_runner_script() {
    log "Creating runner script..."
    
    cat > "$INFOPOINT_DIR/scripts/runner.sh" << 'EOF'
#!/bin/bash

# InfoPoint Kiosk Runner Script
# Starts the kiosk mode environment and URL switcher

export DISPLAY=:0
cd /opt/infopoint

# Wait for X server to be ready
while ! xdpyinfo >/dev/null 2>&1; do
    echo "Waiting for X server..."
    sleep 2
done

# Hide cursor
unclutter -idle 0.5 -root &

# Disable screen saver and power management
xset s off
xset s noblank
xset -dpms

# Set desktop background to black
xsetroot -solid black

# Start window manager
matchbox-window-manager -use_titlebar no &

# Wait a moment for window manager to start
sleep 2

# Start the URL switcher
./scripts/switcher.sh
EOF

    chmod +x "$INFOPOINT_DIR/scripts/runner.sh"
    success "Runner script created"
}

# Function to create package.json
create_package_json() {
    log "Creating package.json..."
    
    cat > "$INFOPOINT_DIR/package.json" << EOF
{
  "name": "infopoint",
  "version": "2.0.0",
  "description": "InfoPoint - Raspberry Pi Kiosk Mode URL Switcher with Timeout Support",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "node index.js"
  },
  "keywords": [
    "raspberry-pi",
    "kiosk",
    "digital-signage",
    "url-switcher",
    "timeout"
  ],
  "author": "Keith Carl",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

    success "Package.json created"
}

# Function to install Node.js dependencies
install_node_dependencies() {
    log "Installing Node.js dependencies..."
    
    cd "$INFOPOINT_DIR"
    sudo -u "$USER" npm install
    
    success "Node.js dependencies installed"
}

# Function to backup existing configuration
backup_existing_config() {
    if [[ -f "$INFOPOINT_DIR/config/urls.json" ]]; then
        log "Backing up existing configuration..."
        cp "$INFOPOINT_DIR/config/urls.json" "$INFOPOINT_DIR/config/urls.json.backup.$(date +%Y%m%d_%H%M%S)"
        success "Configuration backed up"
    fi
}

# Function to enable auto-login
enable_auto_login() {
    log "Configuring auto-login..."
    
    # Enable auto-login for the pi user
    raspi-config nonint do_boot_behaviour B4
    
    success "Auto-login configured"
}

# Function to configure boot behavior
configure_boot_behavior() {
    log "Configuring boot behavior..."
    
    # Add InfoPoint kiosk service to auto-start
    systemctl enable "${SERVICE_NAME}-kiosk.service"
    
    # Create autostart directory for the user
    mkdir -p "/home/$USER/.config/autostart"
    
    # Create desktop entry to start InfoPoint on login
    cat > "/home/$USER/.config/autostart/infopoint.desktop" << EOF
[Desktop Entry]
Type=Application
Name=InfoPoint Kiosk
Exec=systemctl --user start ${SERVICE_NAME}-kiosk
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

    chown "$USER:$USER" "/home/$USER/.config/autostart/infopoint.desktop"
    
    success "Boot behavior configured"
}

# Function to start services
start_services() {
    log "Starting InfoPoint services..."
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME.service"
    systemctl start "$SERVICE_NAME.service"
    
    success "Services started"
}

# Function to display completion message
display_completion() {
    local ip_address=$(get_ip_address)
    local hostname=$(hostname)
    
    echo
    success "============================================"
    success "InfoPoint installation completed successfully!"
    success "============================================"
    echo
    success "Dashboard URLs:"
    success "  http://$ip_address/"
    success "  http://$hostname.local/"
    echo
    success "Configuration:"
    success "  Config file: $INFOPOINT_DIR/config/urls.json"
    success "  Logs: $INFOPOINT_DIR/logs/"
    success "  Service: systemctl status $SERVICE_NAME"
    echo
    success "Next steps:"
    success "1. Access the dashboard using the URLs above"
    success "2. Configure your URLs and timeouts"
    success "3. Click 'APPLY & RESTART' to start kiosk mode"
    echo
    success "For kiosk mode, reboot the system:"
    success "  sudo reboot"
    echo
}

# Main installation function
main() {
    log "Starting InfoPoint installation..."
    
    # Check prerequisites
    if ! command_exists curl; then
        error "curl is required but not installed"
        exit 1
    fi
    
    # Backup existing config if it exists
    backup_existing_config
    
    # Install dependencies
    install_dependencies
    install_nodejs
    
    # Create directory structure
    create_directories
    
    # Create application files
    create_package_json
    install_node_dependencies
    create_service_files
    create_runner_script
    
    # Configure system
    enable_auto_login
    configure_boot_behavior
    start_services
    
    # Display completion message
    display_completion
    
    success "InfoPoint installation completed!"
}

# Handle script interruption
trap 'error "Installation interrupted"; exit 1' INT TERM

# Run main installation
main "$@"
