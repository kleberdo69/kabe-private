#!/system/bin/sh
MODDIR=/data/adb/modules/kabe-v3
DATADIR=/data/adb/kabe
KEYFILE=$DATADIR/key
CFGFILE=$DATADIR/config
LOGFILE=$DATADIR/agent.log
PIDFILE=$DATADIR/pid

mkdir -p $DATADIR 2>/dev/null

# kill old
[ -f $PIDFILE ] && kill -9 $(cat $PIDFILE 2>/dev/null) 2>/dev/null
echo $$ > $PIDFILE

log(){ echo "$(date '+%H:%M:%S') $1" >> $LOGFILE; }

# generate key
if [ ! -f $KEYFILE ]; then
    echo "KABE-$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c8 | tr a-z A-Z)" > $KEYFILE
    chmod 600 $KEYFILE
fi
KEY=$(cat $KEYFILE | tr -d '\n\r ')

# read server
SERVER=$(grep "^server=" $CFGFILE 2>/dev/null | sed 's/^server=//')
[ -z "$SERVER" ] && SERVER="http://192.168.1.20:3000"

DEVICE=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE" ] && DEVICE="android"

log "KEY=$KEY SERVER=$SERVER DEVICE=$DEVICE"

# wait internet
until ping -c1 -W3 8.8.8.8 >/dev/null 2>&1; do sleep 5; done

# register
curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$DEVICE" "$SERVER/api/agent/register" >/dev/null 2>&1
log "registered"

# poll loop
while true; do
    [ -f $DATADIR/stop ] && rm -f $DATADIR/stop && break

    # heartbeat
    curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$DEVICE" "$SERVER/api/agent/register" >/dev/null 2>&1

    # poll command
    R=$(curl -s --connect-timeout 5 "$SERVER/api/agent/poll?key=$KEY" 2>/dev/null)

    if [ -n "$R" ] && [ "$R" != "null" ]; then
        CID=$(echo "$R" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
        CMD=$(echo "$R" | grep -o '"cmd":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$CMD" ] && [ -n "$CID" ]; then
            log "CMD#$CID: $CMD"
            OUT=$(su -c "$CMD" 2>&1)
            RC=$?
            B64=$(echo "$OUT" | base64 -w0 2>/dev/null || echo "$OUT" | base64 2>/dev/null)
            curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$CID" -d "exit=$RC" -d "data=$B64" "$SERVER/api/agent/output" >/dev/null 2>&1
            log "CMD#$CID done rc=$RC"
        fi
    fi

    sleep 2
done

rm -f $PIDFILE
log "stopped"
