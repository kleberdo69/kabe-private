#!/system/bin/sh
# KABE PRIVATE — agent que conecta ao site de qualquer lugar

DATADIR=/data/adb/kabe
MODDIR=/data/adb/modules/kabe-final
KEYFILE=$DATADIR/key
CFGFILE=$DATADIR/config
LOGFILE=$DATADIR/agent.log
PIDFILE=$DATADIR/pid
WWWDIR=$DATADIR/www
PORT=9090

mkdir -p $DATADIR $WWWDIR 2>/dev/null

# kill old
[ -f $PIDFILE ] && kill -9 $(cat $PIDFILE 2>/dev/null) 2>/dev/null
pkill -f "busybox httpd" 2>/dev/null
sleep 1
echo $$ > $PIDFILE

log(){ echo "$(date '+%H:%M:%S') $1" >> $LOGFILE; }

# generate key
if [ ! -f $KEYFILE ]; then
    KEY="KABE-$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c8 | tr a-z A-Z)"
    echo "$KEY" > $KEYFILE
    chmod 600 $KEYFILE
    log "key: $KEY"
fi
KEY=$(cat $KEYFILE | tr -d '\n\r ')

# server
SERVER="https://kabe-private-production.up.railway.app"
echo "server=$SERVER" > $CFGFILE
chmod 600 $CFGFILE

# device
DEVICE=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE" ] && DEVICE="android"

# ip
IP=""
for i in wlan0 eth0 wlan1; do
    IP=$(ip addr show $i 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$IP" ] && break
done

log "KEY=$KEY DEVICE=$DEVICE IP=$IP"

# write key into HTML
cp $MODDIR/webroot/index.html $WWWDIR/index.html 2>/dev/null
sed -i "s/PLACEHOLDER_KEY/$KEY/g" $WWWDIR/index.html 2>/dev/null
sed -i "s/PLACEHOLDER_IP/$IP/g" $WWWDIR/index.html 2>/dev/null

# start httpd
busybox httpd -f -p $PORT -h $WWWDIR &
HTTP_PID=$!
log "webui: http://$IP:$PORT pid=$HTTP_PID"

# wait internet
until ping -c1 -W3 8.8.8.8 >/dev/null 2>&1; do sleep 5; done

# register
curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$DEVICE" "$SERVER/api/agent/register" >/dev/null 2>&1
log "registered"

# poll loop
while true; do
    [ -f $DATADIR/stop ] && rm -f $DATADIR/stop && break

    curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$DEVICE" "$SERVER/api/agent/register" >/dev/null 2>&1

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
            log "CMD#$CID done"
        fi
    fi
    sleep 2
done

kill $HTTP_PID 2>/dev/null
rm -f $PIDFILE
log "stopped"
