#!/system/bin/sh
touch /data/adb/kabe/stop 2>/dev/null
pkill -f kabe-private/service.sh 2>/dev/null
rm -f /data/adb/kabe/service.pid 2>/dev/null
