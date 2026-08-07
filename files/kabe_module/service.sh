#!/system/bin/sh
MODDIR=${0%/*}
LOG="/data/local/tmp/kabe-agent.log"
KEY_FILE="/data/adb/kabe/key"
CONFIG_FILE="/data/adb/kabe/config"

# Wait for boot
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
sleep 15

# Check config
if [ ! -f "$CONFIG_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "[$(date '+%H:%M:%S')] Config not found, skipping" >> $LOG
    exit 0
fi

# Kill existing
pkill -f kabe-agent 2>/dev/null
sleep 2

# Start agent
nohup $MODDIR/system/bin/kabe-agent >> $LOG 2>&1 &
echo "[$(date '+%H:%M:%S')] KABE agent started PID:$!" >> $LOG
