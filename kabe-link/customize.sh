#!/system/bin/sh
# KABE LINK v2.0 — Installer

ui_print ""
ui_print "  KABE LINK v2.0"
ui_print ""

chmod 755 $MODPATH/service.sh
chmod 755 $MODPATH/uninstall.sh

mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe
mkdir -p /data/adb/kabe/www

# Gerar key nova
RANDOM_PART=""
RAW=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
if [ -n "$RAW" ]; then RANDOM_PART=$(echo "$RAW" | tr -d '-' | head -c 16 | tr 'a-z' 'A-Z'); fi
if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(cat /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | head -c 16); fi
if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s%N 2>/dev/null | md5sum | head -c 16 | tr 'a-z' 'A-Z'); fi
if [ -z "$RANDOM_PART" ]; then RANDOM_PART=$(date +%s | md5sum | head -c 16 | tr 'a-z' 'A-Z'); fi
KEY="KABE-${RANDOM_PART}"
echo "$KEY" > /data/adb/kabe/key
chmod 600 /data/adb/kabe/key

echo "server=https://kabe-private-production.up.railway.app" > /data/adb/kabe/config
chmod 600 /data/adb/kabe/config

# Gerar webroot com key embutida
cat > $MODPATH/webroot/index.html << WREOF
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<title>KABE PRIVATE</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#08080c;color:#e8e8ec;min-height:100vh;padding:14px;max-width:400px;margin:0 auto}
.card{background:#111118;border:1px solid #1c1c2a;border-radius:14px;padding:18px;margin-bottom:14px;position:relative;overflow:hidden}
.card::before{content:'';position:absolute;top:0;left:0;right:0;height:1px;background:linear-gradient(90deg,transparent,rgba(220,38,38,.4),transparent)}
.brand{text-align:center;margin-bottom:20px}
.brand h1{font-size:26px;font-weight:900;letter-spacing:4px;background:linear-gradient(135deg,#f87171,#dc2626,#991b1b);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.brand .tag{font-size:9px;color:#444;letter-spacing:4px;text-transform:uppercase;margin-top:4px}
.kb{background:#0a0a10;border:1.5px solid #dc2626;border-radius:10px;padding:20px 14px;text-align:center;margin:14px 0;cursor:pointer}
.kb:active{transform:scale(.97)}
.kb .l{font-size:9px;text-transform:uppercase;letter-spacing:3px;color:#555;margin-bottom:10px}
.kb .v{font-size:15px;font-weight:800;color:#ef4444;font-family:monospace;word-break:break-all;user-select:all;line-height:1.6}
.kb .h{font-size:10px;color:#333;margin-top:10px}
.sr{display:flex;align-items:center;gap:10px;padding:11px 0;border-bottom:1px solid #14141e}
.sr:last-child{border-bottom:none}
.dot{width:9px;height:9px;border-radius:50%;flex-shrink:0;background:#333}
.dot.on{background:#22c55e;box-shadow:0 0 10px rgba(34,197,94,.5)}
.lb{font-size:11px;color:#555;flex:1;text-transform:uppercase;letter-spacing:1.5px}
.vl{font-size:11px;color:#aaa;font-weight:600;font-family:monospace}
.steps{padding:14px;background:#0a0a10;border-radius:8px;border:1px solid #13131d;position:relative;overflow:hidden}
.steps::before{content:'';position:absolute;top:0;left:0;width:2px;height:100%;background:linear-gradient(to bottom,#dc2626,transparent)}
.steps .title{font-size:9px;text-transform:uppercase;letter-spacing:3px;color:#444;margin-bottom:12px;padding-left:10px}
.step{display:flex;gap:10px;padding:6px 0 6px 10px;font-size:11px;color:#555}
.step .n{color:#dc2626;font-weight:800;flex-shrink:0;width:16px;font-size:12px}
.toast{position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(20px);background:linear-gradient(135deg,#dc2626,#991b1b);color:#fff;padding:12px 28px;border-radius:10px;font-size:12px;font-weight:600;z-index:999;display:none;box-shadow:0 8px 30px rgba(220,38,38,.3)}
</style>
</head>
<body>
<div class="card">
  <div class="brand"><h1>KABE PRIVATE</h1><div class="tag">v2.0</div></div>
  <div class="kb" onclick="copyKey()">
    <div class="l">Sua Key</div>
    <div class="v" id="kv">$KEY</div>
    <div class="h">Toque para copiar</div>
  </div>
  <div class="sr"><div class="dot on"></div><span class="lb">Agent</span><span class="vl" style="color:#22c55e">AGUARDANDO</span></div>
  <div class="sr"><span class="lb">Servidor</span><span class="vl" style="color:#22c55e">ONLINE</span></div>
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
function copyKey(){var v=document.getElementById('kv').textContent;if(!v)return;if(navigator.clipboard){navigator.clipboard.writeText(v).then(function(){var t=document.getElementById('toast');t.textContent='Copiado!';t.style.display='block';setTimeout(function(){t.style.display='none'},2200)})}else{var e=document.createElement('textarea');e.value=v;document.body.appendChild(e);e.select();document.execCommand('copy');document.body.removeChild(e);var t=document.getElementById('toast');t.textContent='Copiado!';t.style.display='block';setTimeout(function(){t.style.display='none'},2200)}}
</script>
</body></html>
WREOF

# Copiar tambem pra www
cp -f $MODPATH/webroot/index.html /data/adb/kabe/www/index.html 2>/dev/null

ui_print "  Key: $KEY"
ui_print "  Instalado! Reinicie o celular."
ui_print ""
