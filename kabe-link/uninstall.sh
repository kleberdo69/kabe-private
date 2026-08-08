#!/system/bin/sh
# KABE LINK — Uninstall
rm -rf /data/adb/kabe/link.pid
rm -f /data/adb/kabe/stop
pkill -f kabe-link/service.sh 2>/dev/null
exit 0
