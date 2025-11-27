#!/bin/bash
#
# SEER + Suricata IDS - Complete One-Click Installation
# For Raspberry Pi CM4
#
# This script will:
# 1. Install Suricata IDS with Emerging Threats rules
# 2. Configure SEER integration
# 3. Set up automatic monitoring
# 4. Import existing alerts into database
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/home/admin/seer_install"
DB_PATH="/home/admin/.node-red/seer_database/seer.db"
SURICATA_LOG_DIR="/var/log/suricata"
STATE_DIR="/var/lib/seer"

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     SEER + Suricata IDS - One-Click Installation         ║
║     Raspberry Pi CM4 Edition                             ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ This script must be run as root (use sudo)${NC}"
   exit 1
fi

echo -e "${GREEN}✓ Running as root${NC}"
echo ""

# Detect system
echo -e "${BLUE}[1/10] System Information${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
CPU_CORES=$(nproc)
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

echo "  RAM: ${TOTAL_RAM}MB"
echo "  CPU Cores: ${CPU_CORES}"
echo "  Network Interface: ${INTERFACE}"

if [[ $TOTAL_RAM -lt 1024 ]]; then
    echo -e "${YELLOW}  ⚠ Warning: Less than 1GB RAM. Performance may be limited.${NC}"
fi

sleep 2

# Update system
echo ""
echo -e "${BLUE}[2/10] Updating System${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update -qq
echo -e "${GREEN}  ✓ System updated${NC}"

# Install dependencies
echo ""
echo -e "${BLUE}[3/10] Installing Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  This may take several minutes..."

apt-get install -y -qq \
    suricata \
    jq \
    python3-yaml \
    python3-pip \
    sqlite3 \
    ethtool \
    > /dev/null 2>&1

echo -e "${GREEN}  ✓ Base dependencies installed${NC}"

# Install suricata-update
echo "  Installing suricata-update..."
pip3 install --upgrade suricata-update > /dev/null 2>&1 || {
    apt-get install -y -qq suricata-update > /dev/null 2>&1 || true
}

echo -e "${GREEN}  ✓ All dependencies installed${NC}"

# Configure Suricata
echo ""
echo -e "${BLUE}[4/10] Configuring Suricata${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop Suricata if running
systemctl stop suricata 2>/dev/null || true

# Backup original config
if [[ -f /etc/suricata/suricata.yaml ]]; then
    cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.backup.$(date +%Y%m%d_%H%M%S)
fi

# Update interface in config
sed -i "s/interface: eth0/interface: $INTERFACE/g" /etc/suricata/suricata.yaml

echo -e "${GREEN}  ✓ Suricata configured for interface: ${INTERFACE}${NC}"

# Disable problematic industrial protocol rules
echo ""
echo -e "${BLUE}[5/10] Configuring Rules${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /etc/suricata/disable.conf << 'DISABLE_EOF'
# Disable DNP3 rules (industrial protocol)
2270000
2270001
2270002
2270003
2270004

# Disable Modbus rules (industrial protocol)
2250001
2250002
2250003
2250005
2250006
2250007
2250008
2250009
DISABLE_EOF

echo "  Downloading Emerging Threats rules (~30MB)..."
suricata-update enable-source et/open 2>&1 | grep -v "already enabled" || true
suricata-update --disable-conf=/etc/suricata/disable.conf > /dev/null 2>&1

RULE_COUNT=$(wc -l < /var/lib/suricata/rules/suricata.rules 2>/dev/null || echo "0")
echo -e "${GREEN}  ✓ ${RULE_COUNT} rules installed${NC}"

# Start Suricata
echo ""
echo -e "${BLUE}[6/10] Starting Suricata${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl enable suricata > /dev/null 2>&1
systemctl start suricata

sleep 3

if systemctl is-active --quiet suricata; then
    echo -e "${GREEN}  ✓ Suricata is running${NC}"
else
    echo -e "${RED}  ✗ Suricata failed to start${NC}"
    echo "  Check logs: journalctl -u suricata -n 50"
    exit 1
fi

# Configure SEER integration
echo ""
echo -e "${BLUE}[7/10] Configuring SEER Integration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create directories
mkdir -p "$STATE_DIR"
mkdir -p /var/log/seer
touch "${STATE_DIR}/suricata_eve.pos"

# Set permissions
chmod 644 /var/log/suricata/eve.json 2>/dev/null || true
chmod 644 /var/log/suricata/fast.log 2>/dev/null || true

# Verify database exists
if [[ ! -f "$DB_PATH" ]]; then
    echo -e "${RED}  ✗ SEER database not found: $DB_PATH${NC}"
    echo "  Please run setup_logs.sh first"
    exit 1
fi

echo -e "${GREEN}  ✓ SEER integration configured${NC}"

# Import existing alerts
echo ""
echo -e "${BLUE}[8/10] Importing Existing Alerts${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "${INSTALL_DIR}/script" ]]; then
    # Fix line endings
    sed -i 's/\r$//' "${INSTALL_DIR}/script"
    chmod +x "${INSTALL_DIR}/script"
    
    # Run monitoring script
    cd "$INSTALL_DIR"
    bash "${INSTALL_DIR}/script" > /dev/null 2>&1 || true
    
    # Count imported alerts
    ALERT_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM seer_system_logs WHERE log_type LIKE 'ALERT_%';" 2>/dev/null || echo "0")
    echo -e "${GREEN}  ✓ Imported ${ALERT_COUNT} IDS alerts into database${NC}"
else
    echo -e "${YELLOW}  ⚠ Monitoring script not found${NC}"
fi

# Set up automatic monitoring
echo ""
echo -e "${BLUE}[9/10] Setting Up Automatic Monitoring${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create cron job
CRON_CMD="*/2 * * * * /bin/bash ${INSTALL_DIR}/script >> /var/log/seer/monitor.log 2>&1"

# Check if cron job already exists
if sudo crontab -l 2>/dev/null | grep -q "seer_install/script"; then
    echo -e "${YELLOW}  ⚠ Cron job already exists${NC}"
else
    (sudo crontab -l 2>/dev/null; echo "$CRON_CMD") | sudo crontab -
    echo -e "${GREEN}  ✓ Automatic monitoring enabled (every 2 minutes)${NC}"
fi

# Generate test alert
echo ""
echo -e "${BLUE}[10/10] Testing Installation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  Generating test alert..."
curl -s http://testmynids.org/uid/index.html > /dev/null 2>&1 || true

echo "  Waiting for Suricata to process..."
sleep 10

# Import test alert
cd "$INSTALL_DIR"
bash "${INSTALL_DIR}/script" > /dev/null 2>&1 || true

# Check for test alert
TEST_ALERT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM seer_system_logs WHERE message LIKE '%GPL ATTACK_RESPONSE%' OR message LIKE '%testmynids%';" 2>/dev/null || echo "0")

if [[ $TEST_ALERT -gt 0 ]]; then
    echo -e "${GREEN}  ✓ Test alert detected and imported!${NC}"
else
    echo -e "${YELLOW}  ⚠ Test alert not found yet (may take a moment)${NC}"
fi

# Final summary
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║           ✓ Installation Complete!                       ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${CYAN}Installation Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Suricata IDS:        ${GREEN}Running${NC}"
echo "  Rules Loaded:        ${RULE_COUNT}"
echo "  Monitoring:          ${INTERFACE}"
echo "  Database:            ${DB_PATH}"
echo "  Auto-Update:         Every 2 minutes"
echo ""
echo -e "${CYAN}Quick Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  View dashboard:      bash ${INSTALL_DIR}/seer_dashboard.sh"
echo "  Manual update:       sudo bash ${INSTALL_DIR}/script -v"
echo "  View Suricata logs:  sudo tail -f /var/log/suricata/fast.log"
echo "  View monitor logs:   tail -f /var/log/seer/monitor.log"
echo "  Suricata status:     systemctl status suricata"
echo ""
echo -e "${CYAN}Database Queries:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  View all IDS alerts:"
echo "    sqlite3 ${DB_PATH} \"SELECT * FROM seer_system_logs WHERE log_type LIKE 'ALERT_%' ORDER BY id DESC LIMIT 10;\""
echo ""
echo "  Count alerts by severity:"
echo "    sqlite3 ${DB_PATH} \"SELECT log_type, COUNT(*) FROM seer_system_logs WHERE log_type LIKE 'ALERT_%' GROUP BY log_type;\""
echo ""
echo -e "${YELLOW}Note: Dashboard updates automatically every 2 minutes.${NC}"
echo -e "${YELLOW}      Run 'bash ${INSTALL_DIR}/seer_dashboard.sh' to view now.${NC}"
echo ""
