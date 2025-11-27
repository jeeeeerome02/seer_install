#!/bin/bash
# Reset SEER database and state files

DB_PATH="/home/admin/.node-red/seer_database/seer.db"
STATE_DIR="/var/lib/seer"

echo "SEER Database Reset Tool"
echo "========================"
echo ""
echo "This will:"
echo "  1. Clear all logs from the database"
echo "  2. Reset all state tracking files"
echo ""
read -p "Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled."
    exit 0
fi

# Clear database
if [ -f "$DB_PATH" ]; then
    echo "Clearing database..."
    sqlite3 "$DB_PATH" "DELETE FROM seer_system_logs;"
    sqlite3 "$DB_PATH" "VACUUM;"
    echo "✓ Database cleared"
else
    echo "⚠ Database not found at $DB_PATH"
fi

# Clear state files
if [ -d "$STATE_DIR" ]; then
    echo "Clearing state files..."
    sudo rm -f "$STATE_DIR"/*.state
    sudo rm -f "$STATE_DIR"/*_last_ts
    echo "✓ State files cleared"
else
    echo "⚠ State directory not found at $STATE_DIR"
fi

echo ""
echo "Reset complete! Next run will process logs from the last hour."
