#!/system/bin/sh
touch /data/adb/kabe/stop 2>/dev/null
pkill -f kabe-final/service.sh 2>/dev/null
pkill -f "busybox httpd" 2>/dev/null
