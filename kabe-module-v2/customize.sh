#!/system/bin/sh
ui_print ""
ui_print "  ============================================"
ui_print "        KABE PRIVATE v2.0"
ui_print "  ============================================"
ui_print ""

chmod 755 $MODPATH/service.sh
chmod 755 $MODPATH/webroot/index.html

mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe

if [ ! -f /data/adb/kabe/key ]; then
    KEY="KABE-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8 | tr 'a-z' 'A-Z')"
    echo "$KEY" > /data/adb/kabe/key
    chmod 600 /data/adb/kabe/key
    ui_print "  Key gerada: $KEY"
fi

ui_print "  Instalado!"
ui_print "  Abra a WebUI para configurar"
ui_print ""
