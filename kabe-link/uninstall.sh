#!/system/bin/sh
rm -f /data/adb/kabe/link.pid
pkill -9 -f kabe-link 2>/dev/null
rm -f /data/adb/service.d/kabe-link.sh
exit 0
