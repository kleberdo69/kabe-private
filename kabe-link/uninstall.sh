#!/system/bin/sh
# KABE LINK — Uninstall
rm -rf /data/adb/kabe/link.pid
rm -rf /data/adb/kabe/httpd.pid
rm -f /data/adb/kabe/stop
pkill -9 -f kabe-link 2>/dev/null
pkill -9 -f "busybox httpd.*9090" 2>/dev/null
rm -f /data/adb/service.d/kabe-link.sh
exit 0
