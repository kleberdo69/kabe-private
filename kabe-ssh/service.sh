#!/system/bin/sh
# KABE SSH — SSH reverso que funciona de qualquer lugar
MODDIR=/data/adb/modules/kabe-ssh
DATADIR=/data/adb/kabe-ssh
SSHD_BIN="$MODDIR/system/usr/libexec/ssh-core/sshd"
SSH_BIN="$MODDIR/system/usr/libexec/ssh-core/ssh"
WRAPPER="$MODDIR/system/usr/libexec/ssh-core/wrapper"
LIBDIR="$MODDIR/system/usr/lib"
ETC="$DATADIR/etc"
LOG="$DATADIR/agent.log"
PIDF="$DATADIR/pid"
TUNNEL_PID="$DATADIR/tunnel.pid"
WEBDIR="$DATADIR/www"
PORT=2222

mkdir -p "$DATADIR" "$ETC" "$WEBDIR" 2>/dev/null

# Kill old
[ -f "$PIDF" ] && kill -9 $(cat "$PIDF" 2>/dev/null) 2>/dev/null
[ -f "$TUNNEL_PID" ] && kill -9 $(cat "$TUNNEL_PID" 2>/dev/null) 2>/dev/null
pkill -f "busybox httpd" 2>/dev/null
pkill -f "sshd" 2>/dev/null
sleep 1

log(){ echo "$(date '+[%H:%M:%S]') $1" >> "$LOG"; }
echo $$ > "$PIDF"

# Generate host keys if not exist
SSHD_CORE="$MODDIR/system/usr/libexec/ssh-core"
export LD_LIBRARY_PATH="$LIBDIR"
if [ ! -f "$ETC/ssh_host_rsa_key" ]; then
    "$SSHD_CORE/ssh-keygen" -t rsa -f "$ETC/ssh_host_rsa_key" -N "" 2>/dev/null
fi
if [ ! -f "$ETC/ssh_host_ecdsa_key" ]; then
    "$SSHD_CORE/ssh-keygen" -t ecdsa -f "$ETC/ssh_host_ecdsa_key" -N "" 2>/dev/null
fi
if [ ! -f "$ETC/ssh_host_ed25519_key" ]; then
    "$SSHD_CORE/ssh-keygen" -t ed25519 -f "$ETC/ssh_host_ed25519_key" -N "" 2>/dev/null
fi

# Generate user key for root
if [ ! -f "$ETC/root_key" ]; then
    "$SSHD_CORE/ssh-keygen" -t ed25519 -f "$ETC/root_key" -N "" 2>/dev/null
    mkdir -p /data/adb/kabe-ssh/root/.ssh
    cp "$ETC/root_key.pub" /data/adb/kabe-ssh/root/.ssh/authorized_keys 2>/dev/null
    chmod 700 /data/adb/kabe-ssh/root/.ssh
    chmod 600 /data/adb/kabe-ssh/root/.ssh/authorized_keys
fi

# Create sshd_config
cat > "$ETC/sshd_config" << 'EOF'
Port 2222
ListenAddress 0.0.0.0
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM no
X11Forwarding no
PrintMotd no
PidFile /data/adb/kabe-ssh/sshd.pid
HostKey /data/adb/kabe-ssh/etc/ssh_host_rsa_key
HostKey /data/adb/kabe-ssh/etc/ssh_host_ecdsa_key
HostKey /data/adb/kabe-ssh/etc/ssh_host_ed25519_key
AuthorizedKeysFile /data/adb/kabe-ssh/root/.ssh/authorized_keys
Subsystem sftp /data/adb/modules/kabe-ssh/system/usr/libexec/ssh-core/sftp-server
EOF

# Set root password (padrao: kabe)
echo "root:kabe" | chpasswd 2>/dev/null

# Start sshd
export LD_LIBRARY_PATH="$LIBDIR"
chmod 755 "$SSHD_CORE/sshd" "$SSHD_CORE/ssh" "$SSHD_CORE/wrapper"
"$SSHD_CORE/sshd" -f "$ETC/sshd_config" -E "$LOG" 2>/dev/null
log "sshd started on port $PORT"

# Get IP
IP=""
for i in wlan0 eth0 wlan1; do
    IP=$(ip addr show $i 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    [ -n "$IP" ] && break
done

# Create reverse tunnel via serveo.net
log "starting reverse tunnel..."
chmod 755 "$SSHD_CORE/ssh"
"$SSHD_CORE/ssh" -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R 0:localhost:$PORT serveo.net > "$DATADIR/tunnel.log" 2>&1 &
TUNNEL_PID=$!
echo "$TUNNEL_PID" > "$TUNNEL_PID"

# Wait for tunnel to establish
sleep 5

# Extract public URL from tunnel log
PUB_URL=$(grep -o 'serveo.net:[0-9]*' "$DATADIR/tunnel.log" 2>/dev/null | head -1)
[ -z "$PUB_URL" ] && PUB_URL="aguardando..."

log "tunnel: $PUB_URL"

# Copy WebUI
cp -f "$MODDIR/webroot/index.html" "$WEBDIR/index.html" 2>/dev/null
sed -i "s/PLACEHOLDER_URL/$PUB_URL/g" "$WEBDIR/index.html" 2>/dev/null
sed -i "s/PLACEHOLDER_IP/$IP/g" "$WEBDIR/index.html" 2>/dev/null

# Start httpd
busybox httpd -f -p 9090 -h "$WEBDIR" &
HTTP_PID=$!
log "webui: http://$IP:9090"

# Monitor tunnel - restart if dies
while true; do
    sleep 30
    if ! kill -0 $TUNNEL_PID 2>/dev/null; then
        log "tunnel died, restarting..."
        "$WRAPPER" ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -R 0:localhost:$PORT serveo.net > "$DATADIR/tunnel.log" 2>&1 &
        TUNNEL_PID=$!
        echo "$TUNNEL_PID" > "$TUNNEL_PID"
        sleep 5
        PUB_URL=$(grep -o 'serveo.net:[0-9]*' "$DATADIR/tunnel.log" 2>/dev/null | head -1)
        [ -z "$PUB_URL" ] && PUB_URL="aguardando..."
        log "tunnel restarted: $PUB_URL"
        sed -i "s|aguardando\.\.\.|$PUB_URL|g" "$WEBDIR/index.html" 2>/dev/null
    fi
done
