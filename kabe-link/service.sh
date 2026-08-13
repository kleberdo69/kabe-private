#!/system/bin/sh
# KABE LINK v1.1
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
WEB_PORT=9090
DEFAULT_SERVER="https://kabe-private-production.up.railway.app"

# ===== HTTP helper (curl ou wget) =====
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

# ===== ESPERAR BOOT =====
sleep 8

# ===== CRIAR DIRETORIOS =====
mkdir -p "$DATA_DIR" 2>/dev/null
mkdir -p "$DATA_DIR/www" 2>/dev/null

# ===== KEY =====
if [ ! -f "$KEY_FILE" ]; then
    RANDOM_PART=""
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
log "KABE LINK v1.1 | Key: $KEY | IP: $PHONE_IP | Server: $SERVER_URL"

# ===== MATAR ANTIGOS =====
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null && kill -9 "$OLD_PID" 2>/dev/null
    sleep 1
fi
pkill -f "httpd.*$WEB_PORT" 2>/dev/null
sleep 1

echo $$ > "$PID_FILE"

# ===== INICIAR HTTPD =====
if command -v busybox >/dev/null 2>&1; then
    busybox httpd -f -p $WEB_PORT -h "$DATA_DIR/www" >> "$LOG_FILE" 2>&1 &
elif command -v toybox >/dev/null 2>&1; then
    toybox httpd -p $WEB_PORT -d "$DATA_DIR/www" >> "$LOG_FILE" 2>&1 &
fi
HTTPD_PID=$!
echo "$HTTPD_PID" > "$DATA_DIR/httpd.pid"
log "httpd PID: $HTTPD_PID"

# ===== GERAR HTML =====
generate_html() {
    local ping=$(http_get "$SERVER_URL/api/agent/list")
    local agent_online="false"
    local server_ok="false"
    if [ -n "$ping" ]; then
        echo "$ping" | grep -q "\"key\"" 2>/dev/null && server_ok="true"
        echo "$ping" | grep -q "$KEY" 2>/dev/null && agent_online="true"
    fi

    local ad="dot off"; local at="OFFLINE"; local ac="#666"
    [ "$agent_online" = "true" ] && ad="dot on" && at="ONLINE" && ac="#22c55e"
    local sd="dot off"; local st="ERRO"; local sc="#ef4444"
    [ "$server_ok" = "true" ] && sd="dot on" && st="OK" && sc="#22c55e"
    local pub="Aguardando IP..."
    [ "$PHONE_IP" != "unknown" ] && pub="http://$PHONE_IP:$WEB_PORT"

    cat > "$DATA_DIR/www/index.html" << 'HTMLEOF'
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
.card{background:#111118;border:1px solid #1c1c2a;border-radius:14px;padding:18px;margin-bottom:14px;position:relative;overflow:hidden}
.card::before{content:'';position:absolute;top:0;left:0;right:0;height:1px;background:linear-gradient(90deg,transparent,rgba(220,38,38,.4),transparent)}
.brand{text-align:center;margin-bottom:20px}
.brand h1{font-size:26px;font-weight:900;letter-spacing:4px;background:linear-gradient(135deg,#f87171,#dc2626,#991b1b);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.brand .tag{font-size:9px;color:#444;letter-spacing:4px;text-transform:uppercase;margin-top:4px}
.kb{background:#0a0a10;border:1.5px solid #dc2626;border-radius:10px;padding:20px 14px;text-align:center;margin:14px 0;cursor:pointer;transition:all .2s}
.kb:active{transform:scale(.97)}
.kb .l{font-size:9px;text-transform:uppercase;letter-spacing:3px;color:#555;margin-bottom:10px}
.kb .v{font-size:15px;font-weight:800;color:#ef4444;font-family:monospace;word-break:break-all;user-select:all;line-height:1.6}
.kb .h{font-size:10px;color:#333;margin-top:10px}
.sr{display:flex;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid #14141e}
.sr:last-child{border-bottom:none}
.dot{width:9px;height:9px;border-radius:50%;flex-shrink:0}
.dot.on{background:#22c55e;box-shadow:0 0 10px rgba(34,197,94,.5)}
.dot.off{background:#333}
.lb{font-size:11px;color:#555;flex:1;text-transform:uppercase;letter-spacing:1.5px}
.vl{font-size:11px;color:#aaa;font-weight:600;font-family:monospace}
.steps{padding:14px;background:#0a0a10;border-radius:8px;border:1px solid #13131d;position:relative;overflow:hidden}
.steps::before{content:'';position:absolute;top:0;left:0;width:2px;height:100%;background:linear-gradient(to bottom,#dc2626,transparent)}
.steps .title{font-size:9px;text-transform:uppercase;letter-spacing:3px;color:#444;margin-bottom:12px;padding-left:10px}
.step{display:flex;gap:10px;padding:6px 0 6px 10px;font-size:11px;color:#555}
.step .n{color:#dc2626;font-weight:800;flex-shrink:0;width:16px;font-size:12px}
.toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(20px);background:linear-gradient(135deg,#dc2626,#991b1b);color:#fff;padding:12px 28px;border-radius:10px;font-size:12px;font-weight:600;z-index:999;display:none;box-shadow:0 8px 30px rgba(220,38,38,.3)}
.webui{display:block;text-align:center;padding:14px;background:linear-gradient(135deg,#dc2626,#991b1b);border-radius:10px;color:#fff;text-decoration:none;font-size:13px;font-weight:700;text-transform:uppercase;letter-spacing:2px;margin-top:14px}
.webui:active{opacity:.8}
</style>
</head>
<body>
<div class="bg-glow"></div><div class="bg-glow2"></div>
<div class="card">
  <div class="brand"><h1>KABE PRIVATE</h1><div class="tag">v1.1</div></div>
  <div class="kb" onclick="copyKey()">
    <div class="l">Sua Key</div>
    <div class="v" id="kv">__KEY__</div>
    <div class="h">Toque para copiar</div>
  </div>
  <div class="sr"><div class="__AD__"></div><span class="lb">Agent</span><span class="vl" style="color:__AC__">__AT__</span></div>
  <div class="sr"><div class="__SD__"></div><span class="lb">Servidor</span><span class="vl" style="color:__SC__">__ST__</span></div>
  <div class="sr"><span class="lb">IP</span><span class="vl">__IP__</span></div>
  <div class="sr"><span class="lb">Device</span><span class="vl">__DEV__</span></div>
  <a class="webui" href="http://localhost:9090">Abrir Web UI</a>
</div>
<div class="card">
  <div class="steps"><div class="title">Como usar</div>
    <div class="step"><span class="n">1</span><span>Copie a Key acima</span></div>
    <div class="step"><span class="n">2</span><span>Abra o site KABE PRIVATE</span></div>
    <div class="step"><span class="n">3</span><span>Cole na aba Dispositivo</span></div>
    <div class="step"><span class="n">4</span><span>Use de qualquer lugar</span></div>
  </div>
</div>
<div class="toast" id="toast"></div>
<script>
function toast(m){var t=document.getElementById('toast');t.textContent=m;t.style.display='block';setTimeout(function(){t.style.display='none'},2200)}
function copyKey(){var v=document.getElementById('kv').textContent;if(!v)return;if(navigator.clipboard){navigator.clipboard.writeText(v).then(function(){toast('Copiado!')})}else{var e=document.createElement('textarea');e.value=v;document.body.appendChild(e);e.select();document.execCommand('copy');document.body.removeChild(e);toast('Copiado!')}}
</script>
</body></html>
HTMLEOF

    sed -i "s/__KEY__/$KEY/g" "$DATA_DIR/www/index.html"
    sed -i "s/__AD__/$ad/g" "$DATA_DIR/www/index.html"
    sed -i "s/__AT__/$at/g" "$DATA_DIR/www/index.html"
    sed -i "s/__AC__/$ac/g" "$DATA_DIR/www/index.html"
    sed -i "s/__SD__/$sd/g" "$DATA_DIR/www/index.html"
    sed -i "s/__ST__/$st/g" "$DATA_DIR/www/index.html"
    sed -i "s/__SC__/$sc/g" "$DATA_DIR/www/index.html"
    sed -i "s/__IP__/$PHONE_IP/g" "$DATA_DIR/www/index.html"
    sed -i "s/__DEV__/$DEVICE_ID/g" "$DATA_DIR/www/index.html"

    for wd in /data/adb/modules/kabe-link/webroot /data/adb/ksu/modules/kabe-link/webroot /data/adb/ap/modules/kabe-link/webroot; do
        [ -d "$wd" ] && cp -f "$DATA_DIR/www/index.html" "$wd/index.html" 2>/dev/null
    done
}

generate_html
log "HTML gerado"

# ===== LOOP =====
log "Loop iniciado"
REFRESH=0

while true; do
    if [ -f "$DATA_DIR/stop" ]; then
        rm -f "$DATA_DIR/stop"
        log "Parado"
        break
    fi

    if ! kill -0 $HTTPD_PID 2>/dev/null; then
        log "httpd morreu, reiniciando..."
        pkill -f "httpd.*$WEB_PORT" 2>/dev/null
        sleep 1
        if command -v busybox >/dev/null 2>&1; then
            busybox httpd -f -p $WEB_PORT -h "$DATA_DIR/www" >> "$LOG_FILE" 2>&1 &
        fi
        HTTPD_PID=$!
        echo "$HTTPD_PID" > "$DATA_DIR/httpd.pid"
    fi

    # Heartbeat
    http_post "$SERVER_URL/api/agent/register" "{\"key\":\"$KEY\",\"id\":\"$DEVICE_ID\",\"ip\":\"$PHONE_IP\"}" > /dev/null 2>&1 &

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

    REFRESH=$((REFRESH + 1))
    if [ $REFRESH -ge 10 ]; then
        REFRESH=0
        generate_html
    fi

    sleep 2
done

rm -f "$PID_FILE"
log "KABE LINK parado"
