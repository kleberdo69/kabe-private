#!/system/bin/sh
# Kill old service
pkill -f kabe-link 2>/dev/null
sleep 1

# Clean and recreate module dir
rm -rf /data/adb/modules/kabe-link
mkdir -p /data/adb/modules/kabe-link/webroot

# Copy files
cp /sdcard/Download/kabe/module.prop /data/adb/modules/kabe-link/module.prop
cp /sdcard/Download/kabe/service.sh /data/adb/modules/kabe-link/service.sh
cp /sdcard/Download/kabe/customize.sh /data/adb/modules/kabe-link/customize.sh
cp /sdcard/Download/kabe/uninstall.sh /data/adb/modules/kabe-link/uninstall.sh
cp /sdcard/Download/kabe/webroot/index.html /data/adb/modules/kabe-link/webroot/index.html

# Set permissions
chmod 644 /data/adb/modules/kabe-link/module.prop
chmod 755 /data/adb/modules/kabe-link/service.sh
chmod 755 /data/adb/modules/kabe-link/customize.sh
chmod 755 /data/adb/modules/kabe-link/uninstall.sh
chmod 755 /data/adb/modules/kabe-link/webroot/index.html

# Setup data
mkdir -p /data/adb/kabe/www
mkdir -p /data/adb/service.d

# Generate key
RAW=$(cat /proc/sys/kernel/random/uuid | tr -d '-')
KEY="KABE-$(echo $RAW | tr a-z A-Z | head -c 16)"
echo "$KEY" > /data/adb/kabe/key
chmod 600 /data/adb/kabe/key
echo server=https://kabe-private-production.up.railway.app > /data/adb/kabe/config
chmod 600 /data/adb/kabe/config

echo "KEY=$KEY"

# Start service
nohup sh /data/adb/modules/kabe-link/service.sh > /dev/null 2>&1 &
echo "STARTED"