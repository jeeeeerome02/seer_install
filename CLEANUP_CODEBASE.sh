#!/bin/bash
#
# Remove all unnecessary files from SEER codebase
# Keep only essential files for SEER + Suricata IDS
#

set -euo pipefail

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║     Cleaning Up SEER Codebase                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

cd /home/admin/seer_install

echo "Removing unnecessary files..."
echo ""

# Remove old setup/fix scripts
rm -fv FILE_MONITORING_SETUP.md
rm -fv FIX_INSTRUCTIONS.md
rm -fv cleanup_old_files.sh
rm -fv deploy_fixed_script.sh
rm -fv diagnose_seer.sh
rm -fv fix_line_endings.sh
rm -fv fix_seer_now.sh
rm -fv quick_fix.sh
rm -fv setup_auditd.sh
rm -fv setup_auditd_v2.sh
rm -fv setup_live_monitoring.sh

# Remove test scripts
rm -fv test_events.sh
rm -fv test_file_monitoring.sh
rm -fv test_monitoring.sh
rm -fv test_suricata.sh
rm -fv verify_suricata_seer.sh

# Remove systemd files (using cron instead)
rm -fv seer-monitor-wrapper.sh
rm -fv seer-monitor.service
rm -fv seer-monitor.timer

# Remove from systemd if installed
sudo rm -f /etc/systemd/system/seer-monitor.service
sudo rm -f /etc/systemd/system/seer-monitor.timer
sudo systemctl daemon-reload 2>/dev/null || true

# Remove old firewall logger (replaced by main script)
rm -fv firewall_logger.sh

echo ""
echo "✓ Cleanup complete!"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "ESSENTIAL FILES KEPT:"
echo "═══════════════════════════════════════════════════════════"
ls -lh | grep -E "script|seer_dashboard|setup_logs|setup_suricata|setup_seer_suricata|install_seer|reset_database|INSTALL.md|QUICK_START|SURICATA_IDS|node-red" | awk '{print $9, "(" $5 ")"}'

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "CORE COMPONENTS:"
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ script                              - Main monitoring agent"
echo "  ✓ seer_dashboard.sh                   - Dashboard viewer"
echo "  ✓ setup_logs.sh                       - Initial database setup"
echo "  ✓ setup_suricata_rpi.sh               - Suricata installer"
echo "  ✓ setup_seer_suricata_integration.sh  - Integration setup"
echo "  ✓ install_seer_suricata.sh            - One-click installer"
echo "  ✓ reset_database.sh                   - Database reset tool"
echo "  ✓ node-red                            - Node-RED flows"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "DOCUMENTATION:"
echo "═══════════════════════════════════════════════════════════"
echo "  ✓ INSTALL.md                          - Installation guide"
echo "  ✓ QUICK_START_SURICATA.md             - Quick reference"
echo "  ✓ SURICATA_IDS_INTEGRATION.md         - Full documentation"
echo ""
echo "All unnecessary files have been removed!"
echo ""
