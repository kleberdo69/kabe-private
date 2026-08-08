#!/system/bin/sh
mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe
chmod 755 $MODPATH/service.sh
if [ ! -f /data/adb/kabe/key ]; then
    echo "KABE-$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | head -c8 | tr a-z A-Z)" > /data/adb/kabe/key
    chmod 600 /data/adb/kabe/key
fi
