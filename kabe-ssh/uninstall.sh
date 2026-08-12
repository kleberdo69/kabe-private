#!/system/bin/sh
pkill -f kabe-ssh/service.sh 2>/dev/null
pkill -f sshd 2>/dev/null
pkill -f "busybox httpd" 2>/dev/null
rm -f /data/adb/kabe-ssh/pid /data/adb/kabe-ssh/tunnel.pid 2>/dev/null
