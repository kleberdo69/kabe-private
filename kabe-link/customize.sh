#!/system/bin/sh
# KABE LINK — Installer

ui_print ""
ui_print "  ╔═══════════════════════════════╗"
ui_print "  ║       K A B E   L I N K       ║"
ui_print "  ║         v1.0                  ║"
ui_print "  ╚═══════════════════════════════╝"
ui_print ""

chmod 755 $MODPATH/service.sh

mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe
mkdir -p /data/adb/kabe/www

# Gerar key nova a cada instalacao
RANDOM_PART=""
RAW=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
if [ -n "$RAW" ]; then RANDOM_PART=$(echo "$RAW" | tr -d '-' | head -c 16 | tr 'a-z' 'A-Z'); fi
if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s%N 2>/dev/null | md5sum 2>/dev/null | head -c 16 | tr 'a-z' 'A-Z'); fi
if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(cat /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | head -c 16); fi
if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s | md5sum | head -c 16 | tr 'a-z' 'A-Z'); fi
KEY="KABE-${RANDOM_PART}"
echo "$KEY" > /data/adb/kabe/key
chmod 600 /data/adb/kabe/key
ui_print "  Key: $KEY"

# Config servidor
if [ ! -f /data/adb/kabe/config ]; then
    echo "server=https://kabe-private-production.up.railway.app" > /data/adb/kabe/config
    chmod 600 /data/adb/kabe/config
fi

# Device info
DEVICE_ID=$(getprop ro.product.model 2>/dev/null)
[ -z "$DEVICE_ID" ] && DEVICE_ID="android"
PHONE_IP=""
for iface in wlan0 eth0 wlan1 rmnet0; do
    PHONE_IP=$(ip addr show "$iface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$PHONE_IP" ] && break
done
[ -z "$PHONE_IP" ] && PHONE_IP="unknown"

SERVER_URL=$(grep "^server=" /data/adb/kabe/config 2>/dev/null | cut -d= -f2-)
[ -z "$SERVER_URL" ] && SERVER_URL="https://kabe-private-production.up.railway.app"

# Gerar HTML inicial com dados embutidos
cat > /data/adb/kabe/www/index.html << HTMLEOF
<!DOCTYPE html>
<html lang="pt-BR"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>KABE PRIVATE</title><style>
*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,BlinkMacSystemFont,Roboto,sans-serif;background:#08080c;color:#e8e8ec;min-height:100vh;padding:14px;max-width:400px;margin:0 auto}
.bg-glow{position:fixed;top:-40%;left:-20%;width:80%;height:80%;background:radial-gradient(circle,rgba(220,38,38,.06) 0%,transparent 70%);pointer-events:none;animation:drift 12s ease-in-out infinite alternate}
.bg-glow2{position:fixed;bottom:-30%;right:-20%;width:70%;height:70%;background:radial-gradient(circle,rgba(185,28,28,.05) 0%,transparent 70%);pointer-events:none;animation:drift2 15s ease-in-out infinite alternate}
@keyframes drift{0%{transform:translate(0,0)}100%{transform:translate(30px,40px)}}
@keyframes drift2{0%{transform:translate(0,0)}100%{transform:translate(-20px,-30px)}}
.card{background:#111118;border:1px solid #1c1c2a;border-radius:14px;padding:18px;margin-bottom:14px;overflow:hidden;animation:slideUp .4s ease backwards}
@keyframes slideUp{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:translateY(0)}}
.brand{text-align:center;margin-bottom:20px}
.brand h1{font-size:26px;font-weight:900;letter-spacing:4px;background:linear-gradient(135deg,#f87171,#dc2626,#991b1b);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.brand .tag{font-size:9px;color:#444;letter-spacing:4px;text-transform:uppercase;margin-top:4px}
.kb{background:#0a0a10;border:1.5px solid #dc2626;border-radius:10px;padding:20px 14px;text-align:center;margin:14px 0;cursor:pointer;transition:all .2s}
.kb:active{transform:scale(.97);border-color:#f87171}
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
.t{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(20px);background:linear-gradient(135deg,#dc2626,#991b1b);color:#fff;padding:12px 28px;border-radius:10px;font-size:12px;font-weight:600;z-index:999;display:none;box-shadow:0 8px 30px rgba(220,38,38,.3)}
</style></head><body>
<div class="bg-glow"></div><div class="bg-glow2"></div>
<div class="card">
<div class="brand"><h1>KABE PRIVATE</h1><div class="tag">v1.0</div></div>
<div class="kb" onclick="copyKey()"><div class="l">Sua Key</div><div class="v" id="kv">${KEY}</div><div class="h">Toque para copiar</div></div>
<div class="sr"><div class="dot on"></div><span class="lb">Agent</span><span class="vl" style="color:#22c55e">ONLINE</span></div>
<div class="sr"><div class="lb">IP</span><span class="vl">${PHONE_IP}</span></div>
<div class="sr"><div class="lb">Device</span><span class="vl">${DEVICE_ID}</span></div>
<div class="sr"><div class="lb">Porta</span><span class="vl">9090</span></div>
</div>
<div class="card">
<div class="steps"><div class="title">Como usar</div>
<div class="step"><span class="n">1</span><span>Copie a Key acima</span></div>
<div class="step"><span class="n">2</span><span>Abra o site KABE PRIVATE</span></div>
<div class="step"><span class="n">3</span><span>Cole na aba Dispositivo</span></div>
<div class="step"><span class="n">4</span><span>Use HS / Holograma de qualquer lugar</span></div>
</div></div>
<div class="t" id="toast"></div>
<script>
function toast(m){var t=document.getElementById('toast');t.textContent=m;t.style.display='block';setTimeout(function(){t.style.display='none'},2200)}
function copyKey(){
  var v=document.getElementById('kv').textContent;
  var ta=document.createElement('textarea');ta.value=v;ta.style.position='fixed';ta.style.left='-9999px';
  document.body.appendChild(ta);ta.select();
  try{document.execCommand('copy');toast('Key copiada!');}catch(e){toast('Copie manualmente: '+v);}
  document.body.removeChild(ta);
}
</script></body></html>
HTMLEOF

# Copiar pro webroot do modulo
cp -f /data/adb/kabe/www/index.html $MODPATH/webroot/index.html 2>/dev/null

ui_print "  Instalado!"
ui_print "  Key: $KEY"
ui_print "  Reinicie o celular."
ui_print ""

# ===== INIT.D SUPPORT (funciona sem KernelSU/Magisk) =====
INIT_SCRIPT="/data/adb/service.d/kabe-link.sh"
mkdir -p /data/adb/service.d
cat > "$INIT_SCRIPT" << 'INITEOF'
#!/system/bin/sh
# KABE LINK — init.d boot script
# Roda no boot mesmo sem KernelSU/Magisk
sleep 15
for d in /data/adb/modules/kabe-link /data/adb/ksu/modules/kabe-link /data/adb/ap/modules/kabe-link; do
    if [ -f "$d/service.sh" ]; then
        sh "$d/service.sh" &
        exit 0
    fi
done
INITEOF
chmod 755 "$INIT_SCRIPT"

# Also install as a regular init script for non-Magisk root
ALT_INIT="/data/adb/post-fs-data.d/kabe-link.sh"
mkdir -p /data/adb/post-fs-data.d 2>/dev/null
cat > "$ALT_INIT" << 'INITEOF2'
#!/system/bin/sh
sleep 20
for d in /data/adb/modules/kabe-link /data/adb/ksu/modules/kabe-link /data/adb/ap/modules/kabe-link; do
    if [ -f "$d/service.sh" ]; then
        sh "$d/service.sh" &
        exit 0
    fi
done
INITEOF2
chmod 755 "$ALT_INIT" 2>/dev/null

