#!/system/bin/sh
# KABE LINK — Installer
ui_print ""
ui_print "  ============================================"
ui_print "          KABE LINK v1.0"
ui_print "  ============================================"
ui_print ""

chmod 755 $MODPATH/service.sh

# Criar diretorio de dados
mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe

# Gerar key unica aleatoria
if [ ! -f /data/adb/kabe/key ]; then
    RANDOM_PART=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 16 | tr 'a-z' 'A-Z')
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(date +%s%N 2>/dev/null | md5sum 2>/dev/null | head -c 16 | tr 'a-z' 'A-Z')
    fi
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(cat /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | head -c 16)
    fi
    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > /data/adb/kabe/key
    chmod 600 /data/adb/kabe/key
    ui_print "  Key: $KEY"
fi

# Configura o servidor padrao (site no Railway)
if [ ! -f /data/adb/kabe/config ]; then
    echo "server=https://kabe-private-production.up.railway.app" > /data/adb/kabe/config
    chmod 600 /data/adb/kabe/config
fi

ui_print "  Instalado!"
ui_print "  Abra a WebUI para ver sua key."
ui_print ""
