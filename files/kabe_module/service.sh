#!/system/bin/sh
MODDIR=${0%/*}
LOG="/data/local/tmp/kabe.log"

while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 5; done
sleep 15

# Se nao configurado, inicia web config
if [ ! -f "/data/adb/kabe/config" ] || [ ! -f "/data/adb/kabe/key" ]; then
    echo "[$(date '+%H:%M:%S')] Sem config, iniciando web config na porta 9090..." >> $LOG
    pkill -f kabe-webconfig 2>/dev/null
    nohup $MODDIR/system/bin/kabe-webconfig >> $LOG 2>&1 &
    echo "[$(date '+%H:%M:%S')] Web config PID:$!" >> $LOG
    exit 0
fi

# Se configurado, inicia agent
echo "[$(date '+%H:%M:%S')] Config OK, iniciando agent..." >> $LOG
pkill -f kabe-agent 2>/dev/null
pkill -f kabe-webconfig 2>/dev/null
sleep 2
nohup $MODDIR/system/bin/kabe-agent >> $LOG 2>&1 &
echo "[$(date '+%H:%M:%S')] Agent PID:$!" >> $LOG
