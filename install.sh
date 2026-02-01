#!/bin/bash
# KILLER_VOIDS Install Script - Kali Linux Root + Docker + noVNC + PulseAudio
# Script by: KILLER_VOIDS 🔥
# Work 100% - No Error Guaranteed

echo "[+] KILLER_VOIDS SYSTEM INITIATED - INSTALLATION STARTED 🔥"

# Update system
echo "[+] Updating system packages..."
apt-get update && apt-get upgrade -y

# Install required dependencies
echo "[+] Installing dependencies..."
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    sudo \
    net-tools \
    x11vnc \
    xvfb \
    fluxbox \
    novnc \
    websockify \
    dbus-x11 \
    pulseaudio \
    pulseaudio-utils \
    pavucontrol \
    alsa-utils \
    firefox-esr \
    tigervnc-viewer \
    tigervnc-common \
    tigervnc-xorg-extension

# Install Docker
echo "[+] Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER

# Create necessary directories
echo "[+] Creating directories..."
mkdir -p /opt/novnc
mkdir -p /root/.vnc
mkdir -p /var/run/pulse
mkdir -p /root/.config/pulse

# Configure PulseAudio
echo "[+] Configuring PulseAudio..."
cat > /etc/pulse/system.pa << EOF
load-module module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulse.sock
load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;172.17.0.0/16
load-module module-zeroconf-publish
load-module module-always-sink
load-module module-suspend-on-idle
EOF

# Create PulseAudio daemon script
cat > /usr/local/bin/start-pulseaudio.sh << EOF
#!/bin/bash
pulseaudio --system --disallow-exit --disable-shm=1 --exit-idle-time=-1 &
sleep 2
PULSE_SERVER=unix:/tmp/pulse.sock pacmd load-module module-null-sink sink_name=virtual_speaker
PULSE_SERVER=unix:/tmp/pulse.sock pacmd update-sink-proplist virtual_speaker device.description=Virtual_Speaker
PULSE_SERVER=unix:/tmp/pulse.sock pacmd load-module module-virtual-source source_name=virtual_mic
PULSE_SERVER=unix:/tmp/pulse.sock pacmd update-source-proplist virtual_mic device.description=Virtual_Microphone
EOF

chmod +x /usr/local/bin/start-pulseaudio.sh

# Configure noVNC
echo "[+] Setting up noVNC..."
git clone https://github.com/novnc/noVNC.git /opt/novnc
git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# Create VNC password (change 'voidspass' to your password)
echo "[+] Setting VNC password..."
echo "voidspass" | vncpasswd -f > /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

# Create startup script for X11VNC
cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startfluxbox &
exec /usr/bin/pulseaudio --start --exit-idle-time=-1 --log-target=syslog
EOF

chmod +x /root/.vnc/xstartup

# Create systemd service for noVNC
cat > /etc/systemd/system/novnc.service << EOF
[Unit]
Description=noVNC Service
After=network.target

[Service]
Type=simple
User=root
ExecStart=/opt/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 8080
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for X11VNC
cat > /etc/systemd/system/x11vnc.service << EOF
[Unit]
Description=X11 VNC Server
After=display-manager.service
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/x11vnc -display :0 -noxdamage -forever -shared -rfbauth /root/.vnc/passwd -rfbport 5900 -bg -o /var/log/x11vnc.log
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for PulseAudio
cat > /etc/systemd/system/pulseaudio.service << EOF
[Unit]
Description=PulseAudio System Daemon
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/start-pulseaudio.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create Docker container setup script
cat > /root/setup-docker-desktop.sh << 'EOF'
#!/bin/bash
# Run Kali Linux Desktop in Docker
docker run -d \
  --name kali-desktop \
  --shm-size=2g \
  -p 5901:5900 \
  -p 8081:8080 \
  -e VNC_PASSWORD=voidspass \
  -e RESOLUTION=1920x1080 \
  -v /tmp/pulse.sock:/tmp/pulse.sock \
  -e PULSE_SERVER=unix:/tmp/pulse.sock \
  -v /root/.config/pulse:/root/.config/pulse \
  kalilinux/kali-rolling \
  bash -c "apt update && apt install -y kali-desktop-xfce x11vnc novnc net-tools pulseaudio && \
           echo 'voidspass' | vncpasswd -f > /root/.vncpass && \
           x11vnc -display :0 -forever -shared -rfbauth /root/.vncpass -rfbport 5900 -bg && \
           websockify --web /usr/share/novnc 8080 localhost:5900"
EOF

chmod +x /root/setup-docker-desktop.sh

# Create main startup script
cat > /usr/local/bin/start-kali-desktop.sh << 'EOF'
#!/bin/bash
echo "[+] Starting PulseAudio..."
systemctl start pulseaudio.service
sleep 2

echo "[+] Starting X11VNC..."
systemctl start x11vnc.service
sleep 2

echo "[+] Starting noVNC..."
systemctl start novnc.service
sleep 2

echo "[+] Starting Docker container..."
/root/setup-docker-desktop.sh

echo "[+] Checking services..."
systemctl status pulseaudio.service --no-pager
systemctl status x11vnc.service --no-pager
systemctl status novnc.service --no-pager

echo "[+] Installation Complete!"
echo "[+] Access noVNC at: http://localhost:8080/vnc.html"
echo "[+] Access Docker VNC at: http://localhost:8081/vnc.html"
echo "[+] VNC Password: voidspass"
echo "[+] PulseAudio running on: unix:/tmp/pulse.sock"

# Display network info
echo "[+] Network Information:"
ip addr show | grep inet
netstat -tulpn | grep -E ':(8080|5900)'
EOF

chmod +x /usr/local/bin/start-kali-desktop.sh

# Enable services
systemctl daemon-reload
systemctl enable pulseaudio.service
systemctl enable x11vnc.service
systemctl enable novnc.service

# Create firewall rules
echo "[+] Configuring firewall..."
ufw allow 8080/tcp
ufw allow 5900/tcp
ufw allow 5901/tcp
ufw allow 8081/tcp

# Set permissions
chown -R root:root /opt/novnc
chmod -R 755 /opt/novnc

# Final setup
echo "[+] Running final configuration..."
/usr/local/bin/start-pulseaudio.sh
sleep 2

# Start services
systemctl start pulseaudio.service
systemctl start x11vnc.service
systemctl start novnc.service

# Create test script
cat > /root/test-audio.sh << 'EOF'
#!/bin/bash
echo "[+] Testing PulseAudio..."
pactl info
echo "[+] Listing sinks:"
pactl list sinks
echo "[+] Listing sources:"
pactl list sources
echo "[+] Playing test sound..."
paplay /usr/share/sounds/alsa/Noise.wav
EOF

chmod +x /root/test-audio.sh

echo "[+] KILLER_VOIDS INSTALLATION COMPLETE! 🔥"
echo ""
echo "================================================"
echo "            KALI LINUX DESKTOP READY            "
echo "================================================"
echo "noVNC URL:      http://localhost:8080/vnc.html"
echo "Docker VNC:     http://localhost:8081/vnc.html"
echo "VNC Password:   voidspass"
echo "PulseAudio:     unix:/tmp/pulse.sock"
echo "================================================"
echo ""
echo "Start full desktop: /usr/local/bin/start-kali-desktop.sh"
echo "Test audio: /root/test-audio.sh"
echo "Docker container name: kali-desktop"
echo ""
echo "KILLER_VOIDS SYSTEM READY 😈🔥"
