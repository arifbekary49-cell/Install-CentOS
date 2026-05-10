FROM centos:7

ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# =========================================================
# FIX CENTOS REPO (NO 404)
# =========================================================
RUN rm -rf /etc/yum.repos.d/* && \
    cat > /etc/yum.repos.d/CentOS-Base.repo << 'EOF'
[base]
name=CentOS-7
baseurl=http://vault.centos.org/7.9.2009/os/x86_64/
enabled=1
gpgcheck=0
EOF

# =========================================================
# CORE PACKAGES
# =========================================================
RUN yum clean all || true && yum makecache || true

RUN yum install -y \
    curl wget git sudo bash \
    openssh-server openssh-clients \
    net-tools iproute procps-ng \
    nmap tcpdump traceroute \
    || true

# =========================================================
# SSH
# =========================================================
RUN mkdir -p /var/run/sshd /etc/ssh && \
    ssh-keygen -A || true

RUN echo "root:root" | chpasswd || true

RUN cat > /etc/ssh/sshd_config << 'EOF'
PermitRootLogin yes
PasswordAuthentication yes
UseDNS no
EOF

# =========================================================
# WEB TERMINAL
# =========================================================
RUN curl -L \
    https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    -o /usr/local/bin/ttyd && \
    chmod +x /usr/local/bin/ttyd

# =========================================================
# FILE MANAGER
# =========================================================
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# =========================================================
# SERVICE MANAGER (REAL WORKING systemctl REPLACEMENT)
# =========================================================
RUN mkdir -p /opt/services

RUN cat > /usr/bin/systemctl << 'EOF'
#!/bin/bash

SERVICE="/opt/services/$2.sh"

case "$1" in
  start)
    echo "[SERVICE START] $2"
    bash "$SERVICE" > /dev/null 2>&1 &
    echo $! > "/tmp/$2.pid"
    ;;
  stop)
    echo "[SERVICE STOP] $2"
    kill "$(cat /tmp/$2.pid 2>/dev/null)" 2>/dev/null || true
    ;;
  status)
    if pgrep -f "$2" >/dev/null; then
      echo "$2 RUNNING"
    else
      echo "$2 STOPPED"
    fi
    ;;
  *)
    echo "container systemctl (fake control layer)"
    ;;
esac
EOF

RUN chmod +x /usr/bin/systemctl

# =========================================================
# NET ADMIN SERVICE
# =========================================================
RUN cat > /opt/services/netadmin.sh << 'EOF'
#!/bin/bash
while true; do
  echo "===== NETWORK STATUS ====="
  ip a
  echo ""
  ip r
  echo ""
  ping -c 1 8.8.8.8
  sleep 10
done
EOF

RUN chmod +x /opt/services/netadmin.sh

# =========================================================
# START SCRIPT (FULL PANEL)
# =========================================================
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "===================================="
echo " FULL VPS CONTROL PANEL (RAILWAY)"
echo "===================================="

mkdir -p /var/run/sshd

# SSH
/usr/sbin/sshd || true
echo "SSH: root/root"

# FILE MANAGER
filebrowser -r / -p 8081 --no-auth &
echo "FILE: :8081"

# TERMINAL
ttyd -p 8080 bash &
echo "TERMINAL: :8080"

# START NET ADMIN SERVICE VIA SYSTEMCTL
systemctl start netadmin

echo "SYSTEM READY"

tail -f /dev/null
EOF

RUN chmod +x /start.sh

EXPOSE 22 8080 8081

CMD ["/start.sh"]
