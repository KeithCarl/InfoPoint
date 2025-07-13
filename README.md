# InfoPoint

One-shot setup for Raspberry Pi in kiosk mode as a webpage shuffler with advanced timeout management and a web interface for configuration.

## ✨ New Features

### 🕐 Advanced Timeout Management
- **Individual URL Timeouts**: Set custom display duration for each URL
- **Global Timeout Settings**: Set a default timeout for all URLs
- **Transition Delays**: Add customizable delays between page transitions
- **Real-time Configuration**: Change timeouts without restarting the system

### 🎨 Enhanced Dashboard
- **Modern UI**: Clean, responsive web interface
- **URL Management**: Add, remove, and reorder URLs with ease
- **Display Names**: Assign friendly names to your URLs
- **Live Configuration**: See current settings and modify them instantly

### 🔧 Improved Reliability
- **Better Error Handling**: Graceful handling of network issues and invalid URLs
- **Process Management**: Robust Chromium process management
- **Logging**: Comprehensive logging for troubleshooting
- **Configuration Backup**: Automatic backup of settings

## 🚀 Quick Start

### Prerequisites
- Raspberry Pi (Pi 4 or Pi 5 recommended)
- Raspberry Pi OS with desktop
- Internet connection
- Desktop auto-login enabled (default on RPi OS)

### Installation

1. **Boot into Raspberry Pi desktop**
2. **Ensure network connectivity**
3. **Run the installation command**:

```bash
curl -sSL https://raw.githubusercontent.com/KeithCarl/InfoPoint/main/scripts/setup.sh | sudo bash -
```

That's it! 🎉

## 🖥️ Usage

1. **Access the Dashboard**
   - Visit `http://<pi-ip-address>/` from any device on your network
   - Or use `http://<hostname>.local/` if hostname is configured

2. **Configure URLs**
   - Add URLs you want to display
   - Set individual timeouts for each URL (in milliseconds)
   - Assign display names for easier identification
   - Configure global settings like default timeout and transition delays

3. **Apply Configuration**
   - Click "APPLY & RESTART ⏻" to save and restart kiosk mode
   - The system will reboot into kiosk mode automatically

4. **Kiosk Mode**
   - URLs will cycle automatically with your configured timeouts
   - Each page displays for its specified duration
   - Smooth transitions between pages

## ⚙️ Configuration Options

### URL Settings
- **URL**: The webpage to display
- **Display Name**: Friendly name for identification
- **Timeout**: How long to display this URL (milliseconds)

### Global Settings
- **Default Timeout**: Default duration for new URLs (30000ms = 30 seconds)
- **Transition Delay**: Pause between page changes (2000ms = 2 seconds)

### Example Configuration
```json
{
  "urls": [
    {
      "url": "https://www.example.com/dashboard",
      "name": "Company Dashboard",
      "timeout": 60000
    },
    {
      "url": "https://weather.com",
      "name": "Weather",
      "timeout": 15000
    }
  ],
  "globalTimeout": 30000,
  "transitionDelay": 2000
}
```

## 📁 File Structure

```
/opt/infopoint/
├── index.js              # Main dashboard application
├── package.json          # Node.js dependencies
├── scripts/
│   ├── setup.sh          # Installation script
│   ├── cleanup.sh        # Uninstallation script
│   ├── switcher.sh       # URL switching logic
│   └── runner.sh         # Kiosk mode runner
├── config/
│   ├── urls.json         # URL configuration
│   └── urls.json.backup  # Configuration backup
└── logs/
    └── switcher.log      # Application logs
```

## 🔧 Advanced Configuration

### Manual Configuration
You can manually edit the configuration file:
```bash
sudo nano /opt/infopoint/config/urls.json
```

### Service Management
```bash
# Check dashboard status
sudo systemctl status infopoint

# Check kiosk mode status
sudo systemctl status infopoint-kiosk

# View logs
sudo journalctl -u infopoint -f
```

### Customization
- **Dashboard Port**: Edit `index.js` to change from port 80
- **Browser Behavior**: Modify `scripts/runner.sh` for different display options
- **Timeout Ranges**: Adjust validation in the dashboard code

## 🛠️ Troubleshooting

### Common Issues

**Dashboard not accessible**
- Check if port 80 is available: `sudo netstat -tlnp | grep :80`
- Ensure InfoPoint service is running: `sudo systemctl status infopoint`

**Kiosk mode not starting**
- Check auto-login is enabled: `sudo raspi-config`
- Verify X server is running: `echo $DISPLAY`
- Check kiosk service: `sudo systemctl status infopoint-kiosk`

**URLs not loading**
- Verify internet connectivity: `ping google.com`
- Check URL validity in dashboard
- Review switcher logs: `tail -f /opt/infopoint/logs/switcher.log`

### Log Files
- **Dashboard logs**: `sudo journalctl -u infopoint`
- **Kiosk logs**: `sudo journalctl -u infopoint-kiosk`
- **Switcher logs**: `/opt/infopoint/logs/switcher.log`

## 🔄 Updates

### Updating InfoPoint
Currently, you need to uninstall and reinstall:

1. **Uninstall** (configuration will be backed up):
```bash
sudo /opt/infopoint/scripts/cleanup.sh
```

2. **Reinstall** (will restore backed up configuration):
```bash
curl -sSL https://raw.githubusercontent.com/KeithCarl/InfoPoint/main/scripts/setup.sh | sudo bash -
```

## 🗑️ Uninstallation

To remove InfoPoint completely:
```bash
sudo /opt/infopoint/scripts/cleanup.sh
```

This will:
- Stop all InfoPoint services
- Remove application files
- Backup your configuration
- Restore original boot behavior
- Clean up temporary files

## 💡 Tips & Recommendations

### Hardware
- **Raspberry Pi 4/5**: Best performance for kiosk mode
- **Raspberry Pi Zero**: May struggle with complex websites
- **4GB+ RAM**: Recommended for smooth operation
- **Quality SD Card**: Use Class 10 or better for reliability

### Display
- **Resolution**: 1024x600 minimum for good website compatibility
- **HDMI**: More reliable than DSI displays
- **Screen Burn-in**: Consider varied content to prevent LCD burn-in

### Security
- Change default passwords
- Disable unused services
- Use firewall rules if needed
- Consider OverlayFS for SD card protection

### Network
- Use ethernet when possible for reliability
- Configure static IP for easier access
- Set up hostname for easier discovery

## 📊 Performance Tips

### Optimizing Display Times
- **News sites**: 30-60 seconds
- **Dashboards**: 60-120 seconds  
- **Simple pages**: 15-30 seconds
- **Complex pages**: 45-90 seconds

### Memory Management
- Limit number of URLs (recommended: 10-20)
- Use transition delays to reduce memory pressure
- Restart system daily if needed

## 🤝 Contributing

Feel free to submit issues and pull requests to improve InfoPoint!

## 📄 License

MIT License - see LICENSE file for details

## 🙏 Acknowledgments

- Original inspiration from the Raspberry Pi Foundation's kiosk mode tutorial
- Built upon the excellent work of the PiOSK project
- Thanks to the open-source community for tools and libraries

---

**InfoPoint** - Making digital signage simple and powerful! 🚀
