#!/system/bin/sh
MODDIR=${0%/*}
LOG="/data/local/tmp/kabe.log"
while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
sleep 15
if [ ! -f "/data/adb/kabe/config" ] || [ ! -f "/data/adb/kabe/key" ]; then
    echo "[$(date '+%H:%M:%S')] No config, skipping" >> $LOG
    exit 0
fi
pkill -f kabe-agent 2>/dev/null
sleep 2
nohup $MODDIR/system/bin/kabe-agent >> $LOG 2>&1 &
echo "[$(date '+%H:%M:%S')] Agent started PID:$!" >> $LOG
