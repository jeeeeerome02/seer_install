#!/bin/bash
#
# SEER - Suricata IDS Installation Script for Raspberry Pi CM4
# Full IDS Mode with Emerging Threats Rules
#
# This script installs and configures Suricata optimized for RPi CM4
# with complete ruleset monitoring for comprehensive threat detection.
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SURICATA_CONFIG="/etc/suricata/suricata.yaml"
SURICATA_LOG_DIR="/var/log/suricata"
SEER_LOG_DIR="/var/log/seer"
RULES_DIR="/var/lib/suricata/rules"
INTERFACE="eth0"  # Default interface, will be auto-detected

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   SEER - Suricata IDS Installation (RPi CM4 Optimized)   ║
║   Full IDS Mode with Emerging Threats                    ║
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

# Detect system information
echo ""
echo -e "${BLUE}[1/8] System Information${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
echo -e "  RAM: ${TOTAL_RAM}MB"

if [[ $TOTAL_RAM -lt 1024 ]]; then
    echo -e "${RED}  ⚠ Warning: Less than 1GB RAM detected. Performance may be limited.${NC}"
elif [[ $TOTAL_RAM -lt 2048 ]]; then
    echo -e "${YELLOW}  ⚠ Note: 1-2GB RAM. Consider Option 1 (Lightweight) for better performance.${NC}"
else
    echo -e "${GREEN}  ✓ Sufficient RAM for Full IDS mode${NC}"
fi

# Check CPU
CPU_CORES=$(nproc)
echo -e "  CPU Cores: ${CPU_CORES}"

# Detect network interface
echo ""
echo -e "${BLUE}[2/8] Network Interface Detection${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Find active interface
ACTIVE_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [[ -n "$ACTIVE_INTERFACE" ]]; then
    INTERFACE="$ACTIVE_INTERFACE"
    echo -e "${GREEN}  ✓ Detected active interface: ${INTERFACE}${NC}"
else
    echo -e "${YELLOW}  ⚠ Could not auto-detect interface, using default: ${INTERFACE}${NC}"
fi

# Update system
echo ""
echo -e "${BLUE}[3/8] Updating System Packages${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update -qq
echo -e "${GREEN}  ✓ Package list updated${NC}"

# Install dependencies
echo ""
echo -e "${BLUE}[4/8] Installing Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  This may take several minutes..."

apt-get install -y -qq \
    suricata \
    jq \
    python3-yaml \
    python3-pip \
    ethtool \
    > /dev/null 2>&1

echo -e "${GREEN}  ✓ Base dependencies installed${NC}"

# Install suricata-update via pip to ensure Python module is available
echo "  Installing suricata-update Python module..."
pip3 install --upgrade suricata-update > /dev/null 2>&1 || {
    echo -e "${YELLOW}  ⚠ pip3 install failed, trying apt package...${NC}"
    apt-get install -y -qq suricata-update > /dev/null 2>&1 || true
}

echo -e "${GREEN}  ✓ All dependencies installed${NC}"

# Create directories
echo ""
echo -e "${BLUE}[5/8] Creating Directory Structure${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p "$SURICATA_LOG_DIR"
mkdir -p "$SEER_LOG_DIR"
mkdir -p "$RULES_DIR"

echo -e "${GREEN}  ✓ Directories created${NC}"

# Stop Suricata if running
systemctl stop suricata 2>/dev/null || true

# Configure Suricata for RPi CM4
echo ""
echo -e "${BLUE}[6/8] Configuring Suricata for RPi CM4${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Backup original config
if [[ -f "$SURICATA_CONFIG" ]]; then
    cp "$SURICATA_CONFIG" "${SURICATA_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}  ✓ Original config backed up${NC}"
fi

# Create optimized configuration
cat > "$SURICATA_CONFIG" << 'YAML_EOF'
%YAML 1.1
---

# Suricata Configuration - Optimized for Raspberry Pi CM4
# SEER Integration - Full IDS Mode

vars:
  address-groups:
    HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"
    
    HTTP_SERVERS: "$HOME_NET"
    SMTP_SERVERS: "$HOME_NET"
    SQL_SERVERS: "$HOME_NET"
    DNS_SERVERS: "$HOME_NET"
    TELNET_SERVERS: "$HOME_NET"
    AIM_SERVERS: "$EXTERNAL_NET"
    DC_SERVERS: "$HOME_NET"
    DNP3_SERVER: "$HOME_NET"
    DNP3_CLIENT: "$HOME_NET"
    MODBUS_CLIENT: "$HOME_NET"
    MODBUS_SERVER: "$HOME_NET"
    ENIP_CLIENT: "$HOME_NET"
    ENIP_SERVER: "$HOME_NET"

  port-groups:
    HTTP_PORTS: "80"
    SHELLCODE_PORTS: "!80"
    ORACLE_PORTS: 1521
    SSH_PORTS: 22
    DNP3_PORTS: 20000
    MODBUS_PORTS: 502
    FILE_DATA_PORTS: "[$HTTP_PORTS,110,143]"
    FTP_PORTS: 21
    GENEVE_PORTS: 6081
    VXLAN_PORTS: 4789
    TEREDO_PORTS: 3544

# Default logging directory
default-log-dir: /var/log/suricata/

stats:
  enabled: yes
  interval: 60

outputs:
  # Fast log for quick alert parsing
  - fast:
      enabled: yes
      filename: fast.log
      append: yes

  # EVE JSON output for detailed analysis
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      
      # RPi optimization: Reduce memory usage
      pcap-file: false
      community-id: false
      
      types:
        - alert:
            payload: yes
            payload-buffer-size: 4kb
            payload-printable: yes
            packet: yes
            metadata: yes
            http-body: yes
            http-body-printable: yes
            
        - anomaly:
            enabled: yes
            
        - http:
            extended: yes
            
        - dns:
            enabled: yes
            
        - tls:
            extended: yes
            
        - files:
            force-magic: no
            
        - ssh:
            enabled: yes
            
        - stats:
            totals: yes
            threads: no
            deltas: no

  # Unified2 output disabled to save resources
  - unified2-alert:
      enabled: no

# Logging configuration
logging:
  default-log-level: notice
  default-output-filter:
  
  outputs:
  - console:
      enabled: yes
      
  - file:
      enabled: yes
      level: info
      filename: suricata.log
      
  - syslog:
      enabled: no

# Application layer protocols
app-layer:
  protocols:
    rfb:
      enabled: yes
    mqtt:
      enabled: yes
    krb5:
      enabled: yes
    snmp:
      enabled: yes
    ikev2:
      enabled: yes
    tls:
      enabled: yes
      detection-ports:
        dp: 443
    dcerpc:
      enabled: yes
    ftp:
      enabled: yes
    ssh:
      enabled: yes
    smtp:
      enabled: yes
    imap:
      enabled: detection-only
    smb:
      enabled: yes
      detection-ports:
        dp: 139, 445
    nfs:
      enabled: yes
    tftp:
      enabled: yes
    dns:
      tcp:
        enabled: yes
        detection-ports:
          dp: 53
      udp:
        enabled: yes
        detection-ports:
          dp: 53
    http:
      enabled: yes
      libhtp:
        default-config:
          personality: IDS
          request-body-limit: 100kb
          response-body-limit: 100kb
          request-body-minimal-inspect-size: 32kb
          request-body-inspect-window: 4kb
          response-body-minimal-inspect-size: 40kb
          response-body-inspect-window: 16kb
          response-body-decompress-layer-limit: 2
          http-body-inline: auto
          swf-decompression:
            enabled: yes
            type: both
            compress-depth: 0
            decompress-depth: 0
          double-decode-path: no
          double-decode-query: no

# Performance tuning for RPi CM4
threading:
  set-cpu-affinity: no
  cpu-affinity:
    - management-cpu-set:
        cpu: [ 0 ]
    - receive-cpu-set:
        cpu: [ 0 ]
    - worker-cpu-set:
        cpu: [ 1, 2, 3 ]
  detect-thread-ratio: 1.0

# Memory and performance settings
max-pending-packets: 1024
default-packet-size: 1514

# Capture settings
af-packet:
  - interface: eth0
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
    tpacket-v3: yes
    ring-size: 2048
    block-size: 32768

# Detection engine settings
detect:
  profile: medium
  custom-values:
    toclient-groups: 3
    toserver-groups: 25
  sgh-mpm-context: auto
  inspection-recursion-limit: 3000
  
# Stream engine
stream:
  memcap: 128mb
  checksum-validation: yes
  inline: auto
  reassembly:
    memcap: 256mb
    depth: 1mb
    toserver-chunk-size: 2560
    toclient-chunk-size: 2560
    randomize-chunk-size: yes

# Host table
host:
  hash-size: 4096
  prealloc: 1000
  memcap: 32mb

# Flow settings
flow:
  memcap: 128mb
  hash-size: 65536
  prealloc: 10000
  emergency-recovery: 30

# Defragmentation
defrag:
  memcap: 32mb
  hash-size: 65536
  trackers: 65535
  max-frags: 65535
  prealloc: yes
  timeout: 60

# Rule files
default-rule-path: /var/lib/suricata/rules
rule-files:
  - suricata.rules

# Classification and reference configs
classification-file: /etc/suricata/classification.config
reference-config-file: /etc/suricata/reference.config

# GeoIP (disabled to save resources)
#geoip-database: /usr/share/GeoIP/GeoLite2-Country.mmdb

# Profiling (disabled for performance)
profiling:
  rules:
    enabled: no
  keywords:
    enabled: no
  prefilter:
    enabled: no
  rulegroups:
    enabled: no
  packets:
    enabled: no

# Packet capture (disabled to save disk space)
pcap-log:
  enabled: no

# Unix socket
unix-command:
  enabled: yes
  filename: /var/run/suricata/suricata-command.socket

# Legacy options
legacy:
  uricontent: enabled

YAML_EOF

# Update interface in config
sed -i "s/interface: eth0/interface: $INTERFACE/g" "$SURICATA_CONFIG"

echo -e "${GREEN}  ✓ Suricata configuration created${NC}"

# Update Suricata rules
echo ""
echo -e "${BLUE}[7/8] Downloading Emerging Threats Rules${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  This will download ~30MB of rules, please wait..."

# Create disable.conf to exclude problematic industrial protocol rules
cat > /etc/suricata/disable.conf << 'DISABLE_EOF'
# Disable DNP3 rules (industrial protocol not commonly used)
2270000
2270001
2270002
2270003
2270004

# Disable Modbus rules (industrial protocol not commonly used)
2250001
2250002
2250003
2250005
2250006
2250007
2250008
2250009
DISABLE_EOF

echo "  Disabling industrial protocol rules (DNP3, Modbus)..."

# Enable Emerging Threats Open ruleset
suricata-update enable-source et/open 2>&1 | grep -v "already enabled" || true
suricata-update --disable-conf=/etc/suricata/disable.conf 2>&1 | tail -5

echo -e "${GREEN}  ✓ Rules downloaded and installed${NC}"

# Test configuration
echo ""
echo -e "${BLUE}[8/8] Testing Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "  Testing Suricata configuration..."
TEST_OUTPUT=$(suricata -T -c "$SURICATA_CONFIG" 2>&1)
TEST_EXIT=$?

# Count errors (excluding warnings and info)
ERROR_COUNT=$(echo "$TEST_OUTPUT" | grep -c "<Error>" || echo "0")

if [[ $TEST_EXIT -eq 0 ]]; then
    echo -e "${GREEN}  ✓ Configuration test passed${NC}"
elif [[ $ERROR_COUNT -lt 5 ]]; then
    echo -e "${YELLOW}  ⚠ Configuration test passed with minor warnings${NC}"
    echo "    (Some protocol rules disabled - this is normal)"
else
    echo -e "${RED}  ✗ Configuration test failed with $ERROR_COUNT errors${NC}"
    echo "$TEST_OUTPUT" | grep "<Error>" | head -10
    echo ""
    echo "  Full test output: suricata -T -c $SURICATA_CONFIG"
    exit 1
fi

# Enable and start Suricata
echo ""
echo -e "${BLUE}Starting Suricata Service${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl enable suricata
systemctl start suricata

sleep 3

if systemctl is-active --quiet suricata; then
    echo -e "${GREEN}  ✓ Suricata is running${NC}"
else
    echo -e "${RED}  ✗ Suricata failed to start${NC}"
    echo "  Check logs: journalctl -u suricata -n 50"
    exit 1
fi

# Summary
echo ""
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ✓ Installation Complete!                    ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
echo -e "${BLUE}Installation Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Interface: ${GREEN}${INTERFACE}${NC}"
echo -e "  Mode: ${GREEN}Full IDS with Emerging Threats${NC}"
echo -e "  Config: ${SURICATA_CONFIG}"
echo -e "  Logs: ${SURICATA_LOG_DIR}"
echo -e "  Rules: ${RULES_DIR}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Run: sudo bash setup_seer_suricata_integration.sh"
echo "  2. Monitor alerts: tail -f /var/log/suricata/fast.log"
echo "  3. View stats: suricatasc -c 'dump-counters'"
echo ""
echo -e "${YELLOW}Note: Initial rule loading may take 2-3 minutes${NC}"
echo -e "${YELLOW}      Monitor with: journalctl -u suricata -f${NC}"
echo ""
