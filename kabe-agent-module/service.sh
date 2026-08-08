#!/system/bin/sh
# ═══════════════════════════════════════════════════════
#   KABE Agent — Conexao reversa ao site
#   Roda em background, conecta ao servidor via HTTP
# ═══════════════════════════════════════════════════════

MODDIR=${0%/*}
DATA_DIR="/data/adb/kabe"
KEY_FILE="$DATA_DIR/key"
CONFIG_FILE="$DATA_DIR/config"
LOG_FILE="$DATA_DIR/agent.log"
PID_FILE="$DATA_DIR/agent.pid"

# Server padrao (pode ser alterado no config)
DEFAULT_SERVER="http://localhost:3000"

# Criar diretorio de dados
mkdir -p "$DATA_DIR" 2>/dev/null

# Funcao log
log() {
    echo "$(date '+%H:%M:%S') $1" >> "$LOG_FILE"
    echo "$1"
}

# Funcao curl compativel (usa wget como fallback)
http_get() {
    curl -s --connect-timeout 5 --max-time 10 "$1" 2>/dev/null || \
    wget -q -O - --timeout=10 "$1" 2>/dev/null
}

http_post() {
    curl -s --connect-timeout 5 --max-time 10 -X POST -d "$2" "$1" 2>/dev/null || \
    wget -q -O - --timeout=10 --post-data="$2" "$1" 2>/dev/null
}

# Funcao para ler config
read_config() {
    if [ -f "$CONFIG_FILE" ]; then
        grep "^$1=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2-
    fi
}

# Funcao para salvar config
save_config() {
    local key="$1"
    local value="$2"
    if [ -f "$CONFIG_FILE" ]; then
        # Atualizar existente
        if grep -q "^$key=" "$CONFIG_FILE" 2>/dev/null; then
            sed -i "s|^$key=.*|$key=$value|" "$CONFIG_FILE" 2>/dev/null
        else
            echo "$key=$value" >> "$CONFIG_FILE"
        fi
    else
        echo "$key=$value" > "$CONFIG_FILE"
    fi
}

# ===== GERAR KEY SE NAO EXISTIR =====
if [ ! -f "$KEY_FILE" ]; then
    # Gerar key unica: KABE-XXXXXXXX (8 chars hex uppercase)
    RANDOM_PART=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8 | tr 'a-z' 'A-Z')
    if [ -z "$RANDOM_PART" ]; then
        # Fallback: usa date + random
        RANDOM_PART=$(date +%s | md5sum 2>/dev/null | head -c 8 | tr 'a-z' 'A-Z')
    fi
    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    log "Key gerada: $KEY"
fi

# Ler key
KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r' | xargs)

if [ -z "$KEY" ]; then
    log "ERRO: Key vazia em $KEY_FILE"
    exit 1
fi

# Ler server do config (ou usar padrao)
SERVER_URL=$(read_config "server")
if [ -z "$SERVER_URL" ]; then
    SERVER_URL="$DEFAULT_SERVER"
    save_config "server" "$SERVER_URL"
fi

# Device ID
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | head -c 8)"

# Phone IP
PHONE_IP=""
for iface in wlan0 eth0 wlan1; do
    PHONE_IP=$(ifconfig "$iface" 2>/dev/null | grep 'inet addr' | awk '{print $2}' | cut -d: -f2)
    [ -n "$PHONE_IP" ] && break
done
[ -z "$PHONE_IP" ] && PHONE_IP="unknown"

log "════════════════════════════════════════"
log "KABE Agent iniciado"
log "Key: $KEY"
log "Server: $SERVER_URL"
log "Device: $DEVICE_ID"
log "IP: $PHONE_IP"
log "════════════════════════════════════════"

# ===== MATAR AGENTE ANTIGO =====
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        kill -9 "$OLD_PID" 2>/dev/null
        sleep 1
    fi
fi

# Salvar PID atual
echo $$ > "$PID_FILE"

# ===== REGISTRAR NO SERVIDOR =====
log "Registrando no servidor..."
http_post "$SERVER_URL/api/agent/register" "key=$KEY&id=$DEVICE_ID&ip=$PHONE_IP" > /dev/null 2>&1

# ===== LOOP PRINCIPAL =====
log "Iniciando loop de polling..."

while true; do
    # Verificar se deve parar
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        log "Sinal de parada recebido"
        break
    fi

    # Heartbeat: registrar periodicamente
    http_post "$SERVER_URL/api/agent/register" "key=$KEY&id=$DEVICE_ID&ip=$PHONE_IP" > /dev/null 2>&1 &

    # Poll por comandos
    RESPONSE=$(http_get "$SERVER_URL/api/agent/poll?key=$KEY")

    if [ -n "$RESPONSE" ] && [ "$RESPONSE" != "null" ] && [ "$RESPONSE" != "" ]; then
        # Extrair ID e CMD do JSON
        CMD_ID=$(echo "$RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
        CMD_TEXT=$(echo "$RESPONSE" | grep -o '"cmd":"[^"]*"' | head -1 | cut -d'"' -f4)

        if [ -n "$CMD_TEXT" ] && [ -n "$CMD_ID" ]; then
            log "Executando cmd #$CMD_ID: $CMD_TEXT"

            # Executar comando
            OUTPUT=$(su -c "$CMD_TEXT" 2>&1)
            EXIT_CODE=$?

            # Codificar output em base64
            OUTPUT_B64=$(echo "$OUTPUT" | base64 -w 0 2>/dev/null || echo "$OUTPUT" | base64 2>/dev/null)

            # Enviar output de volta
            http_post "$SERVER_URL/api/agent/output" "key=$KEY&id=$CMD_ID&exit=$EXIT_CODE&data=$OUTPUT_B64" > /dev/null 2>&1 &

            log "Cmd #$CMD_ID concluido (exit=$EXIT_CODE)"
        fi
    fi

    # Aguardar 2 segundos (igual ao exemplo)
    sleep 2
done

# Cleanup
rm -f "$PID_FILE"
log "KABE Agent parado"
