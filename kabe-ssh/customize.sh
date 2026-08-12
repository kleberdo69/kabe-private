#!/system/bin/sh
mkdir -p /data/adb/kabe-ssh/root/.ssh
chmod 700 /data/adb/kabe-ssh/root/.ssh
chmod 755 $MODPATH/service.sh
chmod 755 $MODPATH/system/usr/libexec/ssh-core/*
chmod 755 $MODPATH/system/usr/libexec/ssh-core/wrapper
