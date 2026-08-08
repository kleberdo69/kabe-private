#!/system/bin/sh
# KABE LINK — Installer
# Roda durante a instalação no Magisk/KernelSU

ui_print ""
ui_print "  ╔═══════════════════════════════╗"
ui_print "  ║       K A B E   L I N K       ║"
ui_print "  ║         v1.0                  ║"
ui_print "  ╚═══════════════════════════════╝"
ui_print ""

# Permissoes do service.sh
chmod 755 $MODPATH/service.sh

# Criar diretorio de dados
mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe

# Copiar webroot para o diretorio de dados (garante que existe)
mkdir -p /data/adb/kabe/www
cp -f $MODPATH/webroot/index.html /data/adb/kabe/www/index.html 2>/dev/null
chmod 644 /data/adb/kabe/www/index.html 2>/dev/null

# Gerar key unica aleatoria (sempre gera na instalacao)
if [ -f /data/adb/kabe/key ]; then
    OLD_KEY=$(cat /data/adb/kabe/key 2>/dev/null | tr -d '\n\r')
    ui_print "  Key existente: $OLD_KEY"
else
    RANDOM_PART=""
    # Metodo 1: UUID do kernel
    if [ -z "$RANDOM_PART" ]; then
        RAW=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
        if [ -n "$RAW" ]; then
            RANDOM_PART=$(echo "$RAW" | tr -d '-' | head -c 16 | tr 'a-z' 'A-Z')
        fi
    fi
    # Metodo 2: nanosegundos + md5
    if [ -z "$RANDOM_PART" ]; then
        RAW=$(date +%s%N 2>/dev/null | md5sum 2>/dev/null)
        if [ -n "$RAW" ]; then
            RANDOM_PART=$(echo "$RAW" | head -c 16 | tr 'a-z' 'A-Z')
        fi
    fi
    # Metodo 3: /dev/urandom
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(cat /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | head -c 16)
    fi
    # Metodo 4: fallback absoluto
    if [ -z "$RANDOM_PART" ]; then
        RANDOM_PART=$(date +%s | md5sum | head -c 16 | tr 'a-z' 'A-Z')
    fi

    KEY="KABE-${RANDOM_PART}"
    echo "$KEY" > /data/adb/kabe/key
    chmod 600 /data/adb/kabe/key
    ui_print "  Key: $KEY"
fi

# Configurar servidor padrao
if [ ! -f /data/adb/kabe/config ]; then
    echo "server=https://kabe-private-production.up.railway.app" > /data/adb/kabe/config
    chmod 600 /data/adb/kabe/config
fi

# Limpar dados antigos
rm -f /data/adb/kabe/link.pid 2>/dev/null
rm -f /data/adb/kabe/httpd.pid 2>/dev/null
rm -f /data/adb/kabe/stop 2>/dev/null

ui_print ""
ui_print "  Instalado com sucesso!"
ui_print "  Apos reiniciar, a WebUI fica em:"
ui_print "  http://IP-DO-CELULAR:9090"
ui_print ""
