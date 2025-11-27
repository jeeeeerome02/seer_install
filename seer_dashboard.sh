#!/bin/bash
clear
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           SEER SECURITY MONITORING DASHBOARD               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Statistics (Last 24 Hours)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sqlite3 /home/admin/.node-red/seer_database/seer.db << 'SQL'
SELECT '  Total Events: ' || COUNT(*) FROM seer_system_logs WHERE timestamp >= datetime('now', '-1 day');
SELECT '  Total Alerts: ' || COUNT(*) FROM seer_system_logs WHERE log_type LIKE 'ALERT_%' AND timestamp >= datetime('now', '-1 day');
SELECT '  Logins: ' || COUNT(*) FROM seer_system_logs WHERE log_type = 'LOGIN' AND timestamp >= datetime('now', '-1 day');
SELECT '  Sudo Commands: ' || COUNT(*) FROM seer_system_logs WHERE log_type = 'SUDO' AND timestamp >= datetime('now', '-1 day');
SELECT '  File Access: ' || COUNT(*) FROM seer_system_logs WHERE log_type = 'FILE_ACCESS' AND timestamp >= datetime('now', '-1 day');
SQL

echo ""
echo "📋 Event Types"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sqlite3 /home/admin/.node-red/seer_database/seer.db << 'SQL'
.mode column
.headers off
SELECT '  ' || log_type || ': ' || COUNT(*) 
FROM seer_system_logs 
WHERE timestamp >= datetime('now', '-1 day')
GROUP BY log_type 
ORDER BY COUNT(*) DESC;
SQL

echo ""
echo "🔴 Recent Alerts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sqlite3 /home/admin/.node-red/seer_database/seer.db << 'SQL'
.mode column
.headers on
SELECT substr(timestamp,12,8) as time, substr(log_type,7) as alert, source, substr(message,1,40) as message
FROM seer_system_logs 
WHERE log_type LIKE 'ALERT_%' 
ORDER BY id DESC;
SQL

echo ""
echo "� Recent Activity (All Logs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sqlite3 /home/admin/.node-red/seer_database/seer.db << 'SQL'
.mode column
.headers on
SELECT substr(timestamp,12,8) as time, log_type, source, substr(message,1,45) as activity
FROM seer_system_logs 
ORDER BY id DESC;
SQL

echo ""
echo "Last updated: $(date)"
