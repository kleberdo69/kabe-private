#!/system/bin/sh
# KABE Agent — Uninstaller
# Parar agent
touch /data/adb/kabe/stop 2>/dev/null
pkill -f kabe-agent/service.sh 2>/dev/null
rm -f /data/adb/kabe/agent.pid 2>/dev/null
