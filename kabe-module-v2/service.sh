#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   KABE PRIVATE v2 — Conexao reversa ao site
#   HTTP polling + WebUI via busybox httpd
# ═══════════════════════════════════════════════════════

MODULE_DIR="/data/adb/modules/kabe-private"
DATA_DIR="/data/adb/kabe"
KEY_FILE="$DATA_DIR/key"
CONFIG_FILE="$DATA_DIR/config"
LOG_FILE="$DATA_DIR/service.log"
PID_FILE="$DATA_DIR/service.pid"
HTTPD_PID_FILE="$DATA_DIR/httpd.pid"
HTTP_DIR="$DATA_DIR/www"
HTTP_PORT=9090

# === DIRETORIOS ===
mkdir -p "$DATA_DIR" 2>/dev/null
mkdir -p "$HTTP_DIR" 2>/dev/null

# === MATAR PROCESSOS ANTIGOS ===
for pf in "$PID_FILE" "$HTTPD_PID_FILE"; do
    if [ -f "$pf" ]; then
        OLD=$(cat "$pf" 2>/dev/null)
        [ -n "$OLD" ] && kill -9 "$OLD" 2>/dev/null
    fi
done
pkill -f "busybox httpd" 2>/dev/null
sleep 1

echo $$ > "$PID_FILE"

# === FUNCOES ===
log() { echo "$(date '+[%H:%M:%S]') $1" >> "$LOG_FILE"; }

read_config() {
    [ -f "$CONFIG_FILE" ] && grep "^$1=" "$CONFIG_FILE" 2>/dev/null | sed "s/^$1=//"
}

write_status() {
    local agent_pid=""
    [ -f "$PID_FILE" ] && agent_pid=$(cat "$PID_FILE" 2>/dev/null)
    local agent_running="false"
    [ -n "$agent_pid" ] && kill -0 "$agent_pid" 2>/dev/null && agent_running="true"

    local server_url=$(read_config "server")
    local ip=$(ip addr show wlan0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

    cat > "$DATA_DIR/status.json" << EOF
{"key":"$KEY","server":"$server_url","ip":"$ip","device":"$(getprop ro.product.model)","agent":$agent_running}
EOF
}

# === GERAR KEY ===
if [ ! -f "$KEY_FILE" ]; then
    KEY="KABE-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8 | tr 'a-z' 'A-Z')"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log "Key gerada: $KEY"
fi

KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r ')

# === SERVER ===
SERVER_URL=$(read_config "server")
if [ -z "$SERVER_URL" ]; then
    SERVER_URL="http://192.168.1.20:3000"
    echo "server=$SERVER_URL" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
fi

# === DEVICE ===
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android"

PHONE_IP=""
for iface in wlan0 eth0 wlan1; do
    PHONE_IP=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$PHONE_IP" ] && break
done

log "════════════════════════════════════════"
log "KABE PRIVATE v2 | Key: $KEY"
log "Server: $SERVER_URL | IP: $PHONE_IP"
log "════════════════════════════════════════"

# === COPIAR WEBUI ===
cp -f "$MODULE_DIR/webroot/index.html" "$HTTP_DIR/index.html" 2>/dev/null

# === CRIAR API ENDPOINTS ===
cat > "$HTTP_DIR/key.txt" << EOF
$KEY
EOF

cat > "$HTTP_DIR/status.json" << EOF
{"key":"$KEY","server":"$SERVER_URL","ip":"$PHONE_IP","device":"$DEVICE_ID","agent":true}
EOF

cat > "$HTTP_DIR/save_server.sh" << 'ENDSCRIPT'
#!/bin/sh
read -r DATA
SERVER=$(echo "$DATA" | sed 's/.*server=//')
echo "server=$SERVER" > /data/adb/kabe/config
chmod 600 /data/adb/kabe/config
echo '{"ok":true}'
ENDSCRIPT
chmod 755 "$HTTP_DIR/save_server.sh"

# === INICIAR HTTPD ===
busybox httpd -f -p "$HTTP_PORT" -h "$HTTP_DIR" &
HTTPD_PID=$!
echo "$HTTPD_PID" > "$HTTPD_PID_FILE"
log "WebUI rodando em http://$PHONE_IP:$HTTP_PORT"

# === AGUARDAR INTERNET ===
until ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; do sleep 5; done
log "Internet OK"

# === REGISTRAR ===
curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$DEVICE_ID" -d "ip=$PHONE_IP" "$SERVER_URL/api/agent/register" > /dev/null 2>&1
log "Registrado"

# === STATUS INICIAL ===
write_status

# === LOOP ===
while true; do
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        break
    fi

    # Heartbeat
    curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$DEVICE_ID" -d "ip=$PHONE_IP" "$SERVER_URL/api/agent/register" > /dev/null 2>&1

    # Atualizar status
    write_status

    # Poll comandos
    RESPONSE=$(curl -s --connect-timeout 5 "$SERVER_URL/api/agent/poll?key=$KEY" 2>/dev/null)

    if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ] && [ "$RESPONSE" != "" ]; then
        CMD_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
        CMD_TEXT=$(echo "$RESPONSE" | grep -o '"cmd":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -n "$CMD_TEXT" ] && [ -n "$CMD_ID" ]; then
            log "CMD #$CMD_ID: $CMD_TEXT"
            OUTPUT=$(su -c "$CMD_TEXT" 2>&1)
            EXIT_CODE=$?
            OUTPUT_B64=$(echo "$OUTPUT" | base64 -w 0 2>/dev/null || echo "$OUTPUT" | base64 2>/dev/null)
            curl -s --connect-timeout 5 -X POST -d "key=$KEY" -d "id=$CMD_ID" -d "exit=$EXIT_CODE" -d "data=$OUTPUT_B64" "$SERVER_URL/api/agent/output" > /dev/null 2>&1
            log "CMD #$CMD_ID done (exit=$EXIT_CODE)"
        fi
    fi

    sleep 2
done

# Cleanup
kill $HTTPD_PID 2>/dev/null
rm -f "$PID_FILE" "$HTTPD_PID_FILE"
log "Parado"
