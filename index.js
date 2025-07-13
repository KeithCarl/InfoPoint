const express = require('express');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const app = express();
const PORT = 80;
const CONFIG_FILE = '/opt/infopoint/config/urls.json';
const BACKUP_CONFIG_FILE = '/opt/infopoint/config/urls.json.backup';

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// Default configuration with timeout support
const defaultConfig = {
  urls: [
    { 
      url: 'https://www.raspberrypi.org', 
      timeout: 30000,
      name: 'Raspberry Pi Foundation'
    },
    { 
      url: 'https://github.com/KeithCarl/InfoPoint', 
      timeout: 45000,
      name: 'InfoPoint Repository'
    },
    { 
      url: 'https://www.google.com', 
      timeout: 20000,
      name: 'Google'
    }
  ],
  globalTimeout: 30000, // Default timeout for all URLs
  transitionDelay: 2000 // Delay between page transitions
};

// Ensure config directory exists
const configDir = path.dirname(CONFIG_FILE);
if (!fs.existsSync(configDir)) {
  fs.mkdirSync(configDir, { recursive: true });
}

// Load configuration
function loadConfig() {
  try {
    if (fs.existsSync(CONFIG_FILE)) {
      const data = fs.readFileSync(CONFIG_FILE, 'utf8');
      const config = JSON.parse(data);
      
      // Migrate old config format to new format with timeout support
      if (Array.isArray(config)) {
        const migratedConfig = {
          ...defaultConfig,
          urls: config.map(item => {
            if (typeof item === 'string') {
              return {
                url: item,
                timeout: defaultConfig.globalTimeout,
                name: new URL(item).hostname
              };
            }
            return {
              url: item.url || item,
              timeout: item.timeout || defaultConfig.globalTimeout,
              name: item.name || new URL(item.url || item).hostname
            };
          })
        };
        saveConfig(migratedConfig);
        return migratedConfig;
      }
      
      return { ...defaultConfig, ...config };
    }
    
    // Check for backup config
    if (fs.existsSync(BACKUP_CONFIG_FILE)) {
      const backupData = fs.readFileSync(BACKUP_CONFIG_FILE, 'utf8');
      const backupConfig = JSON.parse(backupData);
      console.log('Restored configuration from backup');
      return { ...defaultConfig, ...backupConfig };
    }
    
    return defaultConfig;
  } catch (error) {
    console.error('Error loading config:', error);
    return defaultConfig;
  }
}

// Save configuration
function saveConfig(config) {
  try {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
    // Create backup
    fs.writeFileSync(BACKUP_CONFIG_FILE, JSON.stringify(config, null, 2));
    console.log('Configuration saved successfully');
  } catch (error) {
    console.error('Error saving config:', error);
  }
}

// Routes
app.get('/', (req, res) => {
  const config = loadConfig();
  
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>InfoPoint Dashboard</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                margin: 0;
                padding: 20px;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                color: #333;
            }
            .container {
                max-width: 1200px;
                margin: 0 auto;
                background: white;
                border-radius: 12px;
                box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                padding: 30px;
            }
            h1 {
                color: #2c3e50;
                text-align: center;
                margin-bottom: 30px;
                font-size: 2.5em;
                font-weight: 300;
            }
            .logo {
                text-align: center;
                margin-bottom: 30px;
            }
            .logo svg {
                width: 80px;
                height: 80px;
                fill: #667eea;
            }
            .settings-panel {
                background: #f8f9fa;
                padding: 20px;
                border-radius: 8px;
                margin-bottom: 30px;
            }
            .settings-row {
                display: flex;
                gap: 20px;
                margin-bottom: 15px;
                align-items: center;
            }
            .settings-row label {
                min-width: 150px;
                font-weight: 500;
            }
            .settings-row input {
                flex: 1;
                padding: 8px 12px;
                border: 2px solid #ddd;
                border-radius: 6px;
                font-size: 14px;
            }
            .url-list {
                margin-bottom: 30px;
            }
            .url-item {
                display: flex;
                gap: 10px;
                margin-bottom: 15px;
                padding: 15px;
                background: #f8f9fa;
                border-radius: 8px;
                align-items: center;
            }
            .url-item input[type="text"] {
                flex: 2;
                padding: 10px;
                border: 2px solid #ddd;
                border-radius: 6px;
                font-size: 14px;
            }
            .url-item input[type="number"] {
                flex: 0 0 120px;
                padding: 10px;
                border: 2px solid #ddd;
                border-radius: 6px;
                font-size: 14px;
            }
            .url-item .name-input {
                flex: 1;
            }
            .url-item button {
                background: #e74c3c;
                color: white;
                border: none;
                padding: 10px 15px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 14px;
                transition: background 0.3s;
            }
            .url-item button:hover {
                background: #c0392b;
            }
            .add-url {
                background: #27ae60;
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 16px;
                margin-bottom: 20px;
                transition: background 0.3s;
            }
            .add-url:hover {
                background: #219a52;
            }
            .apply-btn {
                background: #3498db;
                color: white;
                border: none;
                padding: 15px 30px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 18px;
                font-weight: bold;
                width: 100%;
                margin-top: 20px;
                transition: background 0.3s;
            }
            .apply-btn:hover {
                background: #2980b9;
            }
            .status {
                text-align: center;
                margin-top: 20px;
                padding: 10px;
                border-radius: 6px;
                font-weight: 500;
            }
            .status.success {
                background: #d4edda;
                color: #155724;
                border: 1px solid #c3e6cb;
            }
            .status.error {
                background: #f8d7da;
                color: #721c24;
                border: 1px solid #f5c6cb;
            }
            .timeout-info {
                font-size: 12px;
                color: #666;
                margin-top: 5px;
            }
            .header-row {
                display: flex;
                gap: 10px;
                margin-bottom: 10px;
                padding: 10px 15px;
                background: #34495e;
                color: white;
                border-radius: 6px;
                font-weight: 500;
            }
            .header-row > div:nth-child(1) { flex: 2; }
            .header-row > div:nth-child(2) { flex: 1; }
            .header-row > div:nth-child(3) { flex: 0 0 120px; }
            .header-row > div:nth-child(4) { flex: 0 0 70px; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="logo">
                <svg viewBox="0 0 24 24">
                    <path d="M12 2C13.1 2 14 2.9 14 4C14 5.1 13.1 6 12 6C10.9 6 10 5.1 10 4C10 2.9 10.9 2 12 2M21 9V7L15 1H5C3.89 1 3 1.89 3 3V21C3 22.1 3.89 23 5 23H19C20.1 23 21 22.1 21 21V9M19 21H5V3H13V9H19Z"/>
                </svg>
            </div>
            <h1>InfoPoint Dashboard</h1>
            
            <div class="settings-panel">
                <h3>Global Settings</h3>
                <div class="settings-row">
                    <label>Default Timeout (ms):</label>
                    <input type="number" id="globalTimeout" value="${config.globalTimeout}" min="1000" step="1000">
                </div>
                <div class="settings-row">
                    <label>Transition Delay (ms):</label>
                    <input type="number" id="transitionDelay" value="${config.transitionDelay}" min="0" step="100">
                </div>
                <div class="timeout-info">
                    Timeout determines how long each page is displayed. Transition delay adds a pause between page changes.
                </div>
            </div>
            
            <div class="url-list">
                <h3>URLs to Display</h3>
                <div class="header-row">
                    <div>URL</div>
                    <div>Display Name</div>
                    <div>Timeout (ms)</div>
                    <div>Action</div>
                </div>
                <div id="urlList">
                    ${config.urls.map((item, index) => `
                        <div class="url-item">
                            <input type="text" placeholder="https://example.com" value="${item.url}" data-index="${index}" data-field="url">
                            <input type="text" class="name-input" placeholder="Display Name" value="${item.name || ''}" data-index="${index}" data-field="name">
                            <input type="number" placeholder="30000" value="${item.timeout}" min="1000" step="1000" data-index="${index}" data-field="timeout">
                            <button onclick="removeUrl(${index})">Remove</button>
                        </div>
                    `).join('')}
                </div>
                <button class="add-url" onclick="addUrl()">Add URL</button>
            </div>
            
            <button class="apply-btn" onclick="applyChanges()">APPLY & RESTART ⏻</button>
            
            <div id="status"></div>
        </div>

        <script>
            let urlCount = ${config.urls.length};
            
            function addUrl() {
                const globalTimeout = document.getElementById('globalTimeout').value;
                const urlList = document.getElementById('urlList');
                const newItem = document.createElement('div');
                newItem.className = 'url-item';
                newItem.innerHTML = \`
                    <input type="text" placeholder="https://example.com" value="" data-index="\${urlCount}" data-field="url">
                    <input type="text" class="name-input" placeholder="Display Name" value="" data-index="\${urlCount}" data-field="name">
                    <input type="number" placeholder="30000" value="\${globalTimeout}" min="1000" step="1000" data-index="\${urlCount}" data-field="timeout">
                    <button onclick="removeUrl(\${urlCount})">Remove</button>
                \`;
                urlList.appendChild(newItem);
                urlCount++;
            }
            
            function removeUrl(index) {
                const urlItems = document.querySelectorAll('.url-item');
                urlItems.forEach(item => {
                    const inputs = item.querySelectorAll('input');
                    if (inputs[0] && inputs[0].dataset.index == index) {
                        item.remove();
                    }
                });
            }
            
            function applyChanges() {
                const urls = [];
                const urlItems = document.querySelectorAll('.url-item');
                
                urlItems.forEach(item => {
                    const inputs = item.querySelectorAll('input');
                    const url = inputs[0].value.trim();
                    const name = inputs[1].value.trim();
                    const timeout = parseInt(inputs[2].value) || 30000;
                    
                    if (url) {
                        urls.push({
                            url: url,
                            name: name || new URL(url).hostname,
                            timeout: timeout
                        });
                    }
                });
                
                if (urls.length === 0) {
                    showStatus('At least one URL is required!', 'error');
                    return;
                }
                
                const config = {
                    urls: urls,
                    globalTimeout: parseInt(document.getElementById('globalTimeout').value) || 30000,
                    transitionDelay: parseInt(document.getElementById('transitionDelay').value) || 2000
                };
                
                fetch('/api/urls', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                    },
                    body: JSON.stringify(config)
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        showStatus('Configuration saved! InfoPoint will restart shortly...', 'success');
                        setTimeout(() => {
                            showStatus('Restarting InfoPoint...', 'success');
                        }, 2000);
                    } else {
                        showStatus('Error saving configuration: ' + data.error, 'error');
                    }
                })
                .catch(error => {
                    showStatus('Error: ' + error.message, 'error');
                });
            }
            
            function showStatus(message, type) {
                const status = document.getElementById('status');
                status.textContent = message;
                status.className = 'status ' + type;
            }
        </script>
    </body>
    </html>
  `);
});

// API endpoint to save URLs
app.post('/api/urls', (req, res) => {
  try {
    const config = req.body;
    
    // Validate configuration
    if (!config.urls || !Array.isArray(config.urls) || config.urls.length === 0) {
      return res.json({ success: false, error: 'At least one URL is required' });
    }
    
    // Validate each URL
    for (const item of config.urls) {
      if (!item.url || typeof item.url !== 'string') {
        return res.json({ success: false, error: 'Invalid URL format' });
      }
      
      try {
        new URL(item.url);
      } catch (e) {
        return res.json({ success: false, error: `Invalid URL: ${item.url}` });
      }
      
      if (item.timeout && (typeof item.timeout !== 'number' || item.timeout < 1000)) {
        return res.json({ success: false, error: 'Timeout must be at least 1000ms' });
      }
    }
    
    saveConfig(config);
    
    res.json({ success: true });
    
    // Restart the InfoPoint service after a delay
    setTimeout(() => {
      exec('sudo systemctl restart infopoint', (error) => {
        if (error) {
          console.error('Error restarting InfoPoint service:', error);
        } else {
          console.log('InfoPoint service restarted successfully');
        }
      });
    }, 3000);
    
  } catch (error) {
    console.error('Error in /api/urls:', error);
    res.json({ success: false, error: error.message });
  }
});

// API endpoint to get current configuration
app.get('/api/config', (req, res) => {
  try {
    const config = loadConfig();
    res.json(config);
  } catch (error) {
    res.json({ success: false, error: error.message });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`InfoPoint Dashboard running on port ${PORT}`);
  console.log(`Access the dashboard at: http://localhost:${PORT}/`);
});

// Initialize with default config if none exists
if (!fs.existsSync(CONFIG_FILE)) {
  saveConfig(defaultConfig);
  console.log('Created initial configuration');
}
