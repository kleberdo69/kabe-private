#!/system/bin/sh
# KABE LINK v1.1 — Installer

ui_print ""
ui_print "  ╔═══════════════════════╗"
ui_print "  ║    K A B E   L I N K  ║"
ui_print "  ║         v1.1          ║"
ui_print "  ╚═══════════════════════╝"
ui_print ""

chmod 755 $MODPATH/service.sh

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

# Config
echo "server=https://kabe-private-production.up.railway.app" > /data/adb/kabe/config
chmod 600 /data/adb/kabe/config

ui_print "  Key: $KEY"
ui_print "  Servidor: kabe-private-production.up.railway.app"
ui_print ""

# INIT.D
INIT_SCRIPT="/data/adb/service.d/kabe-link.sh"
mkdir -p /data/adb/service.d
cat > "$INIT_SCRIPT" << 'EOF'
#!/system/bin/sh
sleep 15
for d in /data/adb/modules/kabe-link /data/adb/ksu/modules/kabe-link /data/adb/ap/modules/kabe-link; do
    [ -f "$d/service.sh" ] && sh "$d/service.sh" & exit 0
done
EOF
chmod 755 "$INIT_SCRIPT"

# Also set Magisk service.d
cat > "$MODPATH/service.sh" << 'SEOF'
#!/system/bin/sh
MODDIR=${0%/*}
if [ ! -f "$MODDIR/service.sh" ]; then
    for d in /data/adb/modules/kabe-link /data/adb/ksu/modules/kabe-link /data/adb/ap/modules/kabe-link; do
        [ -f "$d/service.sh" ] && MODDIR="$d" && break
    done
fi
sleep 8
sh "$MODDIR/service.sh" &
SEOF
chmod 755 "$MODPATH/service.sh"

ui_print "  Instalado! Reinicie o celular."
ui_print ""
