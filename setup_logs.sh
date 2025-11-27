#!/bin/bash
# Setup script for SEER monitoring logs and directories

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash setup_logs.sh"
    exit 1
fi

echo "Setting up SEER monitoring environment..."

# Create directories
echo "Creating directories..."
mkdir -p /var/log/seer
mkdir -p /var/lib/seer
mkdir -p /home/admin/.node-red/seer_database

# Set permissions
chmod 755 /var/log/seer
chmod 755 /var/lib/seer
chown -R admin:admin /home/admin/.node-red/seer_database 2>/dev/null || true

# Create empty log files
echo "Creating log files..."
touch /var/log/seer/monitor.log
touch /var/log/seer/firewall.log
chmod 640 /var/log/seer/*.log

# Create logrotate configuration
echo "Configuring log rotation..."
cat > /etc/logrotate.d/seer << 'EOF'
/var/log/seer/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root adm
    sharedscripts
    postrotate
        systemctl reload rsyslog > /dev/null 2>&1 || true
    endscript
}
EOF

# Check if database exists, create if not
DB_PATH="/home/admin/.node-red/seer_database/seer.db"
if [ ! -f "$DB_PATH" ]; then
    echo "Creating database..."
    sqlite3 "$DB_PATH" << 'EOSQL'
CREATE TABLE IF NOT EXISTS seer_system_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    log_type TEXT NOT NULL,
    source TEXT NOT NULL,
    message TEXT NOT NULL,
    extra TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON seer_system_logs(timestamp);
CREATE INDEX IF NOT EXISTS idx_log_type ON seer_system_logs(log_type);
CREATE INDEX IF NOT EXISTS idx_source ON seer_system_logs(source);
CREATE INDEX IF NOT EXISTS idx_created_at ON seer_system_logs(created_at);
EOSQL
    chown admin:admin "$DB_PATH" 2>/dev/null || true
    echo "Database created at $DB_PATH"
else
    echo "Database already exists at $DB_PATH"
fi

# Create simple firewall log if iptables is available
if command -v iptables &>/dev/null; then
    echo "Note: To enable firewall logging, run: sudo bash firewall_logger.sh"
fi

# Test journalctl access
if command -v journalctl &>/dev/null; then
    echo "Journalctl is available - will be used for system logs"
    journalctl -n 1 &>/dev/null && echo "✓ Journalctl access OK" || echo "⚠ Journalctl access may be limited"
else
    echo "⚠ Warning: journalctl not available"
fi

# Summary
echo ""
echo "=========================================="
echo "SEER Setup Complete!"
echo "=========================================="
echo "Directories created:"
echo "  - /var/log/seer (logs)"
echo "  - /var/lib/seer (state files)"
echo "  - /home/admin/.node-red/seer_database (database)"
echo ""
echo "Next steps:"
echo "1. Copy seer_monitor.sh to /usr/local/bin/"
echo "2. Make it executable: chmod +x /usr/local/bin/seer_monitor.sh"
echo "3. (Optional) Setup firewall logging: sudo bash firewall_logger.sh"
echo "4. Test the script: sudo /usr/local/bin/seer_monitor.sh -v"
echo "5. Add to cron: * * * * * /usr/local/bin/seer_monitor.sh"
echo "=========================================="
