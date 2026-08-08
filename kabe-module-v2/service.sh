#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   KABE PRIVATE v2 — Conexao reversa ao site
#   Mesma logica do remote_hs: HTTP polling a cada 2s
# ═══════════════════════════════════════════════════════

MODULE_DIR="/data/adb/modules/kabe-private"
DATA_DIR="/data/adb/kabe"
KEY_FILE="$DATA_DIR/key"
CONFIG_FILE="$DATA_DIR/config"
LOG_FILE="$DATA_DIR/service.log"
PID_FILE="$DATA_DIR/service.pid"
DEST="/data/user/0/com.dts.freefireth/files/contentcache/Compulsory/android/gameassetbundles"
GAME_FILE="cache_res.~2BrPJlgpDAnfyUCp~2Biox5bwsZlQQ~3D"

# === DIRETORIOS ===
mkdir -p "$DATA_DIR" 2>/dev/null
mkdir -p "$MODULE_DIR/logs" 2>/dev/null

# === FUNCOES ===
log() {
    echo "$(date '+[%H:%M:%S]') $1" >> "$LOG_FILE"
}

http_get() {
    curl -s --connect-timeout 5 --max-time 10 "$1" 2>/dev/null
}

http_post() {
    curl -s --connect-timeout 5 --max-time 10 -X POST -d "$2" "$1" 2>/dev/null
}

read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        grep "^$1=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2-
    fi
}

save_config() {
    local key="$1"
    local value="$2"
    if [ -f "$CONFIG_FILE" ]; then
        if grep -q "^$key=" "$CONFIG_FILE" 2>/dev/null; then
            sed -i "s|^$key=.*|$key=$value|" "$CONFIG_FILE" 2>/dev/null
        else
            echo "$key=$value" >> "$CONFIG_FILE"
        fi
    else
        echo "$key=$value" > "$CONFIG_FILE"
    fi
}

# === GERAR KEY SE NAO EXISTIR ===
if [ ! -f "$KEY_FILE" ]; then
    RANDOM_PART=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8 | tr 'a-z' 'A-Z')
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(date +%s | md5sum 2>/dev/null | head -c 8 | tr 'a-z' 'A-Z')
    fi
    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log "Key gerada: $KEY"
fi

# LER KEY
KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r' | xargs)
if [ -z "$KEY" ]; then
    log "ERRO: Key vazia"
    exit 1
fi

# LER SERVER
SERVER_URL=$(read_config "server")
if [ -z "$SERVER_URL" ]; then
    SERVER_URL="http://192.168.1.20:3000"
    save_config "server" "$SERVER_URL"
fi

# DEVICE INFO
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android-unknown"

PHONE_IP=""
for iface in wlan0 eth0 wlan1; do
    PHONE_IP=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$PHONE_IP" ] && break
done
[ -z "$PHONE_IP" ] && PHONE_IP="unknown"

# === MATAR PROCESSO ANTIGO ===
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null
        sleep 1
    fi
fi
echo $$ > "$PID_FILE"

log "════════════════════════════════════════"
log "KABE PRIVATE v2 — Iniciado"
log "Key: $KEY"
log "Server: $SERVER_URL"
log "Device: $DEVICE_ID"
log "IP: $PHONE_IP"
log "════════════════════════════════════════"

# === AGUARDAR INTERNET ===
log "Aguardando internet..."
until ping -c 1 8.8.8.8 >/dev/null 2>&1; do
    sleep 3
done
log "Internet OK"

# === REGISTRAR NO SERVIDOR ===
log "Registrando no servidor..."
http_post "$SERVER_URL/api/agent/register" "key=$KEY&id=$DEVICE_ID&ip=$PHONE_IP" > /dev/null 2>&1

# === ESTADOS ANTERIORES ===
LAST_HS=""
LAST_STATUS=""

# === LOOP PRINCIPAL (igual ao remote_hs: poll a cada 2s) ===
log "Monitorando comandos..."

while true; do
    # Verificar sinal de parada
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        log "Sinal de parada recebido"
        break
    fi

    # Heartbeat: re-registrar
    http_post "$SERVER_URL/api/agent/register" "key=$KEY&id=$DEVICE_ID&ip=$PHONE_IP" > /dev/null 2>&1 &

    # Poll por comandos
    RESPONSE=$(http_get "$SERVER_URL/api/agent/poll?key=$KEY")

    if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ] && [ "$RESPONSE" != "" ]; then
        # Extrair ID e CMD do JSON
        CMD_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
        CMD_TEXT=$(echo "$RESPONSE" | grep -o '"cmd":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -n "$CMD_TEXT" ] && [ -n "$CMD_ID" ]; then
            log "Executando cmd #$CMD_ID: $CMD_TEXT"

            # Executar comando via su
            OUTPUT=$(su -c "$CMD_TEXT" 2>&1)
            EXIT_CODE=$?

            # Enviar output de volta
            OUTPUT_B64=$(echo "$OUTPUT" | base64 -w 0 2>/dev/null || echo "$OUTPUT" | base64 2>/dev/null)
            http_post "$SERVER_URL/api/agent/output" "key=$KEY&id=$CMD_ID&exit=$EXIT_CODE&data=$OUTPUT_B64" > /dev/null 2>&1 &

            log "Cmd #$CMD_ID concluido (exit=$EXIT_CODE)"
        fi
    fi

    sleep 2
done

# Cleanup
rm -f "$PID_FILE"
log "KABE PRIVATE v2 parado"
