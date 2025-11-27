# SEER Monitor Installation Guide

## Files Overview

- **script** - Main monitoring script (seer_monitor.sh)
- **setup_logs.sh** - Initial setup script
- **firewall_logger.sh** - Firewall logging configuration
- **reset_database.sh** - Database reset utility
- **test_events.sh** - Generate test security events

## Installation Steps

### 1. Initial Setup

Copy all files to your Linux system and run the setup script:

```bash
# Copy files to Linux system
# Then run:
sudo bash setup_logs.sh
```

This creates:
- `/var/log/seer/` - Log directory
- `/var/lib/seer/` - State files directory
- `/home/admin/.node-red/seer_database/seer.db` - SQLite database

### 2. Install Main Script

```bash
sudo cp script /usr/local/bin/seer_monitor.sh
sudo chmod +x /usr/local/bin/seer_monitor.sh
sudo sed -i 's/\r$//' /usr/local/bin/seer_monitor.sh
```

### 3. (Optional) Setup Firewall Logging

If you want to monitor firewall events:

```bash
sudo bash firewall_logger.sh
```

This configures iptables to log dropped packets.

### 4. Test the Script

```bash
# Run with verbose output
sudo /usr/local/bin/seer_monitor.sh -v
```

### 5. Generate Test Events

```bash
sudo bash test_events.sh
```

Then run the monitor again to capture the events:

```bash
sudo /usr/local/bin/seer_monitor.sh -v
```

### 6. Check Database

```bash
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT id, timestamp, log_type, source, message FROM seer_system_logs ORDER BY id DESC LIMIT 20;"
```

### 7. Setup Cron Job

Add to root's crontab to run every minute:

```bash
sudo crontab -e
```

Add this line:

```
* * * * * /usr/local/bin/seer_monitor.sh
```

Or for more frequent monitoring (every 5 seconds using staggered jobs):

```
* * * * * /usr/local/bin/seer_monitor.sh
* * * * * sleep 5; /usr/local/bin/seer_monitor.sh
* * * * * sleep 10; /usr/local/bin/seer_monitor.sh
* * * * * sleep 15; /usr/local/bin/seer_monitor.sh
* * * * * sleep 20; /usr/local/bin/seer_monitor.sh
* * * * * sleep 25; /usr/local/bin/seer_monitor.sh
* * * * * sleep 30; /usr/local/bin/seer_monitor.sh
* * * * * sleep 35; /usr/local/bin/seer_monitor.sh
* * * * * sleep 40; /usr/local/bin/seer_monitor.sh
* * * * * sleep 45; /usr/local/bin/seer_monitor.sh
* * * * * sleep 50; /usr/local/bin/seer_monitor.sh
* * * * * sleep 55; /usr/local/bin/seer_monitor.sh
```

## What Gets Monitored

The script monitors these event types using **journald** (systemd journal):

1. **LOGIN** - SSH login attempts (successful and failed)
2. **SUDO** - Sudo command executions
3. **SYSLOG** - System warnings and errors
4. **KERNEL** - Kernel events (USB, network changes, crashes)
5. **CRON** - Cron job executions
6. **USER_MGMT** - User account changes
7. **SERVICE** - Failed systemd services
8. **PACKAGE** - Package installations (from dpkg.log)
9. **FIREWALL** - Network traffic (if configured)
10. **FAILED_LOGIN** - Failed login records (from btmp)

## Alerts Generated

The script generates alerts for:

- **BRUTE_FORCE** - Multiple failed login attempts
- **ROOT_LOGIN_ATTEMPT** - Failed root login
- **ROOT_LOGIN_SUCCESS** - Successful root login
- **SUDO_FAILURE** - Failed sudo attempts
- **DANGEROUS_SUDO** - Dangerous commands (rm, dd, mkfs, etc.)
- **SYSTEM_CRITICAL** - OOM, kernel panic
- **DISK_CRITICAL** - Disk full
- **PROCESS_CRASH** - Segfaults
- **PORT_SCAN** - Potential port scanning
- **USB_DEVICE** - USB device connected
- **NETWORK_CHANGE** - Network interface changes
- **ACCOUNT_CHANGE** - User/group modifications
- **SERVICE_FAILED** - Failed systemd services

## Viewing Logs

### Monitor Log File

```bash
tail -f /var/log/seer/monitor.log
```

### Query Database

```bash
# Recent events
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT * FROM seer_system_logs ORDER BY id DESC LIMIT 50;"

# Only alerts
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT * FROM seer_system_logs WHERE log_type LIKE 'ALERT_%' ORDER BY id DESC;"

# Failed logins
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT * FROM seer_system_logs WHERE log_type = 'LOGIN' AND message LIKE '%Failed%';"

# Sudo commands
sqlite3 /home/admin/.node-red/seer_database/seer.db \
  "SELECT * FROM seer_system_logs WHERE log_type = 'SUDO' ORDER BY id DESC LIMIT 20;"
```

## Troubleshooting

### No events logged

1. Check if script runs without errors:
   ```bash
   sudo /usr/local/bin/seer_monitor.sh -v
   ```

2. Check journalctl access:
   ```bash
   journalctl -n 10
   ```

3. Generate test events:
   ```bash
   sudo bash test_events.sh
   ```

### Timestamps look wrong

Clear state files and re-run:
```bash
sudo bash reset_database.sh
```

### Script hangs

Check if another instance is running:
```bash
ps aux | grep seer_monitor
```

Remove lock file if needed:
```bash
sudo rm -f /var/run/seer_monitor.lock
```

## Maintenance

### Reset Database

```bash
sudo bash reset_database.sh
```

### View Script Help

```bash
/usr/local/bin/seer_monitor.sh --help
```

### Check Disk Space

```bash
du -sh /var/log/seer/
du -sh /home/admin/.node-red/seer_database/
```

## Security Notes

- The script runs as root to access system logs
- Database is stored in user directory (admin)
- Logs are rotated automatically (7 days retention)
- State files track last processed positions to avoid duplicates
