#!/system/bin/sh
su -c 'pkill -f kabe-link'
sleep 2
su -c 'rm -rf /data/adb/modules/kabe-link'
su -c 'mkdir -p /data/adb/modules/kabe-link'
su -c 'cd /data/adb/modules/kabe-link && unzip -o /sdcard/Download/kabe-link.zip'
su -c 'chmod -R 755 /data/adb/modules/kabe-link/service.sh /data/adb/modules/kabe-link/customize.sh /data/adb/modules/kabe-link/uninstall.sh'
su -c 'chmod -R 755 /data/adb/modules/kabe-link/webroot'
su -c 'nohup sh /data/adb/modules/kabe-link/service.sh > /dev/null 2>&1 &'
echo DONE