#!/system/bin/sh
touch /data/adb/kabe/stop 2>/dev/null
pkill -f kabe-v3/service.sh 2>/dev/null
