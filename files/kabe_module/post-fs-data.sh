#!/system/bin/sh
MODDIR=${0%/*}
mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe
chmod 755 $MODDIR/system/bin/kabe-agent
chmod 755 $MODDIR/system/bin/kabe-setup
