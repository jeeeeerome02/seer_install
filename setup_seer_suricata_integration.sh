#!/bin/bash
#
# SEER - Suricata Integration Setup
# Configures Suricata to work with SEER monitoring system
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SEER_DIR="/home/admin/seer_install"
SURICATA_LOG_DIR="/var/log/suricata"
SURICATA_EVE_LOG="${SURICATA_LOG_DIR}/eve.json"
SURICATA_FAST_LOG="${SURICATA_LOG_DIR}/fast.log"
STATE_DIR="/var/lib/seer"

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║        SEER ↔ Suricata Integration Setup                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}✗ This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Check if Suricata is installed
if ! command -v suricata &> /dev/null; then
    echo -e "${RED}✗ Suricata is not installed${NC}"
    echo "  Run: sudo bash setup_suricata_rpi.sh"
    exit 1
fi

echo -e "${GREEN}✓ Suricata is installed${NC}"

# Check if Suricata is running
if ! systemctl is-active --quiet suricata; then
    echo -e "${YELLOW}⚠ Suricata is not running, starting...${NC}"
    systemctl start suricata
    sleep 2
fi

if systemctl is-active --quiet suricata; then
    echo -e "${GREEN}✓ Suricata is running${NC}"
else
    echo -e "${RED}✗ Failed to start Suricata${NC}"
    exit 1
fi

# Create state directory
echo ""
echo -e "${BLUE}[1/4] Setting Up Directories${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "$STATE_DIR"
touch "${STATE_DIR}/suricata_eve.pos"
touch "${STATE_DIR}/suricata_fast.pos"

echo -e "${GREEN}  ✓ State directory created${NC}"

# Set permissions
echo ""
echo -e "${BLUE}[2/4] Setting Permissions${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Allow SEER monitoring script to read Suricata logs
chmod 644 "${SURICATA_EVE_LOG}" 2>/dev/null || true
chmod 644 "${SURICATA_FAST_LOG}" 2>/dev/null || true
chmod 755 "${SURICATA_LOG_DIR}"

echo -e "${GREEN}  ✓ Permissions configured${NC}"

# Create log rotation config
echo ""
echo -e "${BLUE}[3/4] Configuring Log Rotation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /etc/logrotate.d/suricata-seer << 'LOGROTATE_EOF'
/var/log/suricata/*.log /var/log/suricata/*.json {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        systemctl reload suricata > /dev/null 2>&1 || true
    endscript
}
LOGROTATE_EOF

echo -e "${GREEN}  ✓ Log rotation configured${NC}"

# Test log access
echo ""
echo -e "${BLUE}[4/4] Testing Log Access${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$SURICATA_EVE_LOG" ]]; then
    echo -e "${GREEN}  ✓ EVE JSON log exists${NC}"
    
    # Check if we can read it
    if [[ -r "$SURICATA_EVE_LOG" ]]; then
        echo -e "${GREEN}  ✓ EVE JSON log is readable${NC}"
        
        # Count alerts
        ALERT_COUNT=$(grep -c '"event_type":"alert"' "$SURICATA_EVE_LOG" 2>/dev/null || echo "0")
        echo -e "    Current alerts in log: ${ALERT_COUNT}"
    else
        echo -e "${RED}  ✗ EVE JSON log is not readable${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ EVE JSON log not found (will be created when alerts occur)${NC}"
fi

if [[ -f "$SURICATA_FAST_LOG" ]]; then
    echo -e "${GREEN}  ✓ Fast log exists${NC}"
else
    echo -e "${YELLOW}  ⚠ Fast log not found (will be created when alerts occur)${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║           ✓ Integration Setup Complete!                  ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${BLUE}Integration Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Suricata Logs: ${SURICATA_LOG_DIR}"
echo -e "  EVE JSON: ${SURICATA_EVE_LOG}"
echo -e "  Fast Log: ${SURICATA_FAST_LOG}"
echo -e "  State Dir: ${STATE_DIR}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  The monitoring script has been updated to process Suricata alerts."
echo ""
echo "  1. Run monitoring: sudo bash ${SEER_DIR}/script -v"
echo "  2. View dashboard: bash ${SEER_DIR}/seer_dashboard.sh"
echo ""
echo -e "${BLUE}Testing:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Generate test alert:"
echo "    curl http://testmynids.org/uid/index.html"
echo ""
echo "  Monitor Suricata:"
echo "    tail -f ${SURICATA_FAST_LOG}"
echo ""
echo -e "${YELLOW}Note: It may take 1-2 minutes for Suricata to start detecting${NC}"
echo ""
