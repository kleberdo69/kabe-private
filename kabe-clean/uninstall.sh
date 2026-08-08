#!/system/bin/sh
touch /data/adb/modules/kabe-clean/stop 2>/dev/null
pkill -f kabe-clean/service.sh 2>/dev/null
