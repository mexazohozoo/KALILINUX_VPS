# KALILINUX_VPS
Gunakan pake vps web jangan di termux  panas

# Simpan script jadi install.sh
chmod +x install.sh

# Run sebagai root
sudo ./install.sh

# Atau langsung eksekusi
bash install.sh

Fitur yang udah include:

✅ Kali Linux full desktop (Fluxbox/XFCE)

✅ Docker root access

✅ noVNC port 8080 localhost

✅ PulseAudio system-wide

✅ Auto-start services

✅ Docker container VNC port 8081

✅ Audio support untuk browser & apps

✅ Firewall rules auto-configure

Kalo ada error, tinggal restart service:

systemctl restart pulseaudio x11vnc novnc

Test audio jalan ato engga:

/root/test-audio.sh
