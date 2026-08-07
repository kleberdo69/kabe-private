#!/system/bin/sh
# KABE Private - service.sh (start after boot)
MODDIR=${0%/*}
LOG="/data/local/tmp/kabe.log"

log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> $LOG
}

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 5
done
sleep 10

log_msg "Boot complete, starting KABE server..."

# Kill any existing instance
pkill -f "kabe-server" 2>/dev/null
sleep 1

# Start server
$MODDIR/system/bin/kabe-server >> $LOG 2>&1 &
log_msg "KABE server started (PID: $!)"
