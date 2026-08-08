#!/system/bin/sh
mkdir -p /data/adb/modules/kabe-clean
chmod 755 $MODPATH/service.sh
if [ ! -f /data/adb/modules/kabe-clean/key ]; then
    echo "KABE-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c8 | tr a-z A-Z)" > /data/adb/modules/kabe-clean/key
    chmod 600 /data/adb/modules/kabe-clean/key
fi
