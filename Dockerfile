FROM centos:7

ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# =========================================================
# FIX CENTOS 7 REPO (NO 404 - VULTR CENTOS VAULT)
# =========================================================
RUN rm -rf /etc/yum.repos.d/* && \
    cat > /etc/yum.repos.d/CentOS-Base.repo << 'EOF'
[base]
name=CentOS-7
baseurl=http://vault.centos.org/7.9.2009/os/x86_64/
enabled=1
gpgcheck=0

[updates]
name=CentOS-7-Updates
baseurl=http://vault.centos.org/7.9.2009/updates/x86_64/
enabled=1
gpgcheck=0

[extras]
name=CentOS-7-Extras
baseurl=http://vault.centos.org/7.9.2009/extras/x86_64/
enabled=1
gpgcheck=0
EOF

# =========================================================
# YUM FIX
# =========================================================
RUN yum clean all || true && yum makecache || true

# =========================================================
# CORE PACKAGES (STABLE ONLY)
# =========================================================
RUN yum install -y \
    curl wget git sudo bash \
    openssh-server openssh-clients \
    net-tools iproute procps-ng \
    || true

# =========================================================
# SSH SETUP
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
# WEB TERMINAL (GOTTY)
# =========================================================
RUN curl -L \
    https://github.com/yudai/gotty/releases/latest/download/gotty_linux_amd64 \
    -o /usr/local/bin/gotty && \
    chmod +x /usr/local/bin/gotty

# =========================================================
# FILE MANAGER (FILEBROWSER)
# =========================================================
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# =========================================================
# SAFE SYSTEMCTL (NO CRASH)
# =========================================================
RUN echo -e '#!/bin/bash\necho "systemctl disabled in container"\nexit 0' > /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl

# =========================================================
# START SCRIPT (ALL SERVICES)
# =========================================================
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "===================================="
echo "  VPS PANEL STARTING (FIXED)"
echo "===================================="

mkdir -p /var/run/sshd

# START SSH
/usr/sbin/sshd || true
echo "SSH READY -> root/root"

# START FILE MANAGER
filebrowser -r / -p 8081 --no-auth &
echo "FILE ACCESS -> http://localhost:8081"

# START WEB TERMINAL
/usr/local/bin/gotty -p 8080 bash &
echo "TERMINAL -> http://localhost:8080"

echo "SYSTEM RUNNING WITHOUT systemd ERRORS"

tail -f /dev/null
EOF

RUN chmod +x /start.sh

# =========================================================
# PORTS
# =========================================================
EXPOSE 22 8080 8081

CMD ["/start.sh"]
