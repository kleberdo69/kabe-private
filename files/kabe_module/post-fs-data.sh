#!/system/bin/sh
# KABE Private - post-fs-data
MODDIR=${0%/*}
mkdir -p /data/adb/kabe
chmod 700 /data/adb/kabe
chmod 755 $MODDIR/system/bin/kabe-server
chmod 755 $MODDIR/system/bin/kabe-keygen
