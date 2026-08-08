#!/system/bin/sh
# KABE Agent — Installer
ui_print ""
ui_print "  ============================================"
ui_print "          KABE Agent v1.0"
ui_print "  ============================================"
ui_print ""

# Permissoes
chmod 755 $MODPATH/service.sh

# Criar diretorio de dados
mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe

# Gerar key se nao existe
if [ ! -f /data/adb/kabe/key ]; then
    KEY="KABE-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c 8 | tr 'a-z' 'A-Z')"
    echo "$KEY" > /data/adb/kabe/key
    chmod 600 /data/adb/kabe/key
    ui_print "  Key gerada: $KEY"
fi

ui_print "  Instalado com sucesso!"
ui_print "  Abra a WebUI para ver sua key"
ui_print ""
