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

# ===== ESPERAR BOOT =====
sleep 5

# ===== CRIAR DIRETORIOS =====
mkdir -p "$DATA_DIR" 2>/dev/null
mkdir -p "$DATA_DIR/www" 2>/dev/null

# ===== GERAR KEY SE NAO EXISTIR =====
if [ ! -f "$KEY_FILE" ]; then
    RANDOM_PART=""
    RAW=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    if [ -n "$RAW" ]; then RANDOM_PART=$(echo "$RAW" | tr -d '-' | head -c 16 | tr 'a-z' 'A-Z'); fi
    if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s%N 2>/dev/null | md5sum 2>/dev/null | head -c 16 | tr 'a-z' 'A-Z'); fi
    if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(cat /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | head -c 16); fi
    if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s | md5sum | head -c 16 | tr 'a-z' 'A-Z'); fi
    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
fi

KEY=$(cat "$KEY_FILE" 2>/dev/null | tr -d '\n\r' | xargs)
[ -z "$KEY" ] && exit 1

# Server
if [ -f "$CONFIG_FILE" ]; then SERVER_URL=$(grep "^server=" "$CONFIG_FILE" 2>/dev/null | cut -d= -f2-); fi
[ -z "$SERVER_URL" ] && SERVER_URL="$DEFAULT_SERVER"

# Device info
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android"

PHONE_IP=""
for iface in wlan0 eth0 wlan1 rmnet0; do
    PHONE_IP=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$PHONE_IP" ] && break
done
[ -z "$PHONE_IP" ] && PHONE_IP="unknown"

# ===== LOG =====
log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG_FILE"; }
log "KABE LINK v1.0 | Key: $KEY | IP: $PHONE_IP"

# ===== MATAR ANTIGOS =====
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null && kill -9 "$OLD_PID" 2>/dev/null
    sleep 1
fi
pkill -f "busybox httpd.*$WEB_PORT" 2>/dev/null
sleep 1

echo $$ > "$PID_FILE"

# ===== INICIAR HTTPD =====
busybox httpd -f -p $WEB_PORT -h "$DATA_DIR/www" >> "$LOG_FILE" 2>&1 &
HTTPD_PID=$!
echo "$HTTPD_PID" > "$DATA_DIR/httpd.pid"
log "httpd PID: $HTTPD_PID"

# ===== GERAR HTML DINAMICO =====
generate_html() {
    local agent_online="false"
    local server_ok="false"

    local ping=$(curl -s --connect-timeout 3 --max-time 5 "$SERVER_URL/api/agent/list" 2>/dev/null)
    if [ -n "$ping" ] && echo "$ping" | grep -q "key"; then
        server_ok="true"
        echo "$ping" | grep -q "$KEY" && agent_online="true"
    fi

    local agent_dot="dot off"
    local agent_txt="OFFLINE"
    local agent_color="#666"
    if [ "$agent_online" = "true" ]; then
        agent_dot="dot on"
        agent_txt="ONLINE"
        agent_color="#22c55e"
    fi

    local server_dot="dot off"
    local server_txt="ERRO"
    local server_color="#ef4444"
    if [ "$server_ok" = "true" ]; then
        server_dot="dot on"
        server_txt="OK"
        server_color="#22c55e"
    fi

    local public_url="Aguardando IP..."
    [ "$PHONE_IP" != "unknown" ] && public_url="http://$PHONE_IP:$WEB_PORT"

    cat > "$DATA_DIR/www/index.html" << HTMLEOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>KABE PRIVATE</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#08080c;color:#e8e8ec;min-height:100vh;padding:14px;max-width:400px;margin:0 auto}
.bg-glow{position:fixed;top:-40%;left:-20%;width:80%;height:80%;background:radial-gradient(circle,rgba(220,38,38,.06) 0%,transparent 70%);pointer-events:none;animation:drift 12s ease-in-out infinite alternate}
.bg-glow2{position:fixed;bottom:-30%;right:-20%;width:70%;height:70%;background:radial-gradient(circle,rgba(185,28,28,.05) 0%,transparent 70%);pointer-events:none;animation:drift2 15s ease-in-out infinite alternate}
@keyframes drift{0%{transform:translate(0,0)}100%{transform:translate(30px,40px)}}
@keyframes drift2{0%{transform:translate(0,0)}100%{transform:translate(-20px,-30px)}}
.card{background:#111118;border:1px solid #1c1c2a;border-radius:14px;padding:18px;margin-bottom:14px;position:relative;overflow:hidden;animation:slideUp .4s ease backwards}
.card:nth-child(2){animation-delay:.1s}
.card::before{content:'';position:absolute;top:0;left:0;right:0;height:1px;background:linear-gradient(90deg,transparent,rgba(220,38,38,.4),transparent)}
@keyframes slideUp{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}
.brand{text-align:center;margin-bottom:20px}
.brand h1{font-size:26px;font-weight:900;letter-spacing:4px;background:linear-gradient(135deg,#f87171,#dc2626,#991b1b);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.brand .tag{font-size:9px;color:#444;letter-spacing:4px;text-transform:uppercase;margin-top:4px}
.key-box{background:#0a0a10;border:1.5px solid #dc2626;border-radius:10px;padding:20px 14px;text-align:center;margin:14px 0;cursor:pointer;transition:all .2s}
.key-box:active{transform:scale(.97);border-color:#f87171}
.key-box .lbl{font-size:9px;text-transform:uppercase;letter-spacing:3px;color:#555;margin-bottom:10px}
.key-box .key{font-size:15px;font-weight:800;color:#ef4444;font-family:monospace;word-break:break-all;user-select:all;line-height:1.6}
.key-box .hint{font-size:10px;color:#333;margin-top:10px}
.status-row{display:flex;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid #14141e}
.status-row:last-child{border-bottom:none}
.dot{width:9px;height:9px;border-radius:50%;flex-shrink:0}
.dot.on{background:#22c55e;box-shadow:0 0 10px rgba(34,197,94,.5)}
.dot.off{background:#333}
.lbl2{font-size:11px;color:#555;flex:1;text-transform:uppercase;letter-spacing:1.5px}
.val{font-size:11px;color:#aaa;font-weight:600;font-family:monospace}
.link-box{background:#0a0a10;border:1px solid #1a1a26;border-radius:8px;padding:14px;margin-top:14px;cursor:pointer;transition:all .2s}
.link-box:active{border-color:#dc2626;transform:scale(.98)}
.link-box .lbl{font-size:9px;text-transform:uppercase;letter-spacing:3px;color:#444;margin-bottom:6px}
.link-box .url{font-size:11px;color:#ef4444;font-family:monospace;word-break:break-all}
.link-box .hint{font-size:10px;color:#2a2a2a;margin-top:6px}
.steps{padding:14px;background:#0a0a10;border-radius:8px;border:1px solid #13131d;position:relative;overflow:hidden}
.steps::before{content:'';position:absolute;top:0;left:0;width:2px;height:100%;background:linear-gradient(to bottom,#dc2626,transparent);border-radius:1px}
.steps .title{font-size:9px;text-transform:uppercase;letter-spacing:3px;color:#444;margin-bottom:12px;padding-left:10px}
.steps .step{display:flex;gap:10px;padding:6px 0 6px 10px;font-size:11px;color:#555}
.steps .step .n{color:#dc2626;font-weight:800;flex-shrink:0;width:16px;font-size:12px}
.toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(20px);background:linear-gradient(135deg,#dc2626,#991b1b);color:#fff;padding:12px 28px;border-radius:10px;font-size:12px;font-weight:600;z-index:999;display:none;box-shadow:0 8px 30px rgba(220,38,38,.3)}
</style>
</head>
<body>
<div class="bg-glow"></div>
<div class="bg-glow2"></div>
<div class="card">
  <div class="brand"><h1>KABE PRIVATE</h1><div class="tag">v1.0</div></div>
  <div class="key-box" onclick="copyText('${KEY}')">
    <div class="lbl">Sua Key</div>
    <div class="key">${KEY}</div>
    <div class="hint">Toque para copiar</div>
  </div>
  <div class="status-row">
    <div class="${agent_dot}"></div>
    <span class="lbl2">Agent</span>
    <span class="val" style="color:${agent_color}">${agent_txt}</span>
  </div>
  <div class="status-row">
    <div class="${server_dot}"></div>
    <span class="lbl2">Servidor</span>
    <span class="val" style="color:${server_color}">${server_txt}</span>
  </div>
  <div class="status-row">
    <span class="lbl2">IP</span>
    <span class="val">${PHONE_IP}</span>
  </div>
  <div class="status-row">
    <span class="lbl2">Device</span>
    <span class="val">${DEVICE_ID}</span>
  </div>
  <div class="status-row">
    <span class="lbl2">Porta</span>
    <span class="val">${WEB_PORT}</span>
  </div>
  <div class="link-box" onclick="copyText('${public_url}')">
    <div class="lbl">Acesso Remoto</div>
    <div class="url">${public_url}</div>
    <div class="hint">Toque para copiar</div>
  </div>
</div>
<div class="card">
  <div class="steps">
    <div class="title">Como usar</div>
    <div class="step"><span class="n">1</span><span class="t">Copie a Key acima</span></div>
    <div class="step"><span class="n">2</span><span class="t">Abra o site KABE PRIVATE</span></div>
    <div class="step"><span class="n">3</span><span class="t">Cole na aba Dispositivo</span></div>
    <div class="step"><span class="n">4</span><span class="t">Use HS / Holograma de qualquer lugar</span></div>
  </div>
</div>
<div class="toast" id="toast"></div>
<script>
function toast(m){var t=document.getElementById('toast');t.textContent=m;t.style.display='block';setTimeout(function(){t.style.display='none'},2200)}
function copyText(t){if(navigator.clipboard){navigator.clipboard.writeText(t).then(function(){toast('Copiado!')})}else{var e=document.createElement('textarea');e.value=t;document.body.appendChild(e);e.select();document.execCommand('copy');document.body.removeChild(e);toast('Copiado!')}}
</script>
</body>
</html>
HTMLEOF
}

# ===== GERAR HTML INICIAL =====
generate_html

# ===== LOOP PRINCIPAL =====
log "Loop iniciado"
REFRESH=0

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
        busybox httpd -f -p $WEB_PORT -h "$DATA_DIR/www" >> "$LOG_FILE" 2>&1 &
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
            log "cmd #$CMD_ID ok"
        fi
    fi

    # Regenerar HTML a cada 10 ciclos (~20s) pra atualizar status
    REFRESH=$((REFRESH + 1))
    if [ $REFRESH -ge 10 ]; then
        REFRESH=0
        generate_html
    fi

    sleep 2
done

rm -f "$PID_FILE"
log "KABE LINK parado"
