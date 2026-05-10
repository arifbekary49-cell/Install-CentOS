FROM centos:7

ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# =========================================================
# FIX CENTOS REPO (YOUR OLD STYLE BUT STABLE)
# =========================================================
RUN rm -rf /etc/yum.repos.d/* && \
    curl -fsSL -o /etc/yum.repos.d/CentOS-Base.repo \
    https://raw.githubusercontent.com/CentOS/sig-cloud-instance-images/CentOS-7/docker/centos-7.repo

# =========================================================
# FIX NETWORK (RAILWAY SAFE DNS)
# =========================================================
RUN echo "nameserver 1.1.1.1" > /etc/resolv.conf || true && \
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf || true

# =========================================================
# YUM FIX
# =========================================================
RUN yum clean all || true && yum makecache || true

# =========================================================
# CORE PACKAGES (MIXED FROM YOUR OLD STACK BUT SAFE)
# =========================================================
RUN yum install -y \
    curl wget git sudo bash \
    openssh-server openssh-clients \
    net-tools iproute procps-ng \
    nano vim \
    || true

# =========================================================
# SSH FIX (FROM YOUR OLD CODE)
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
# WEB TERMINAL (FROM MODERN FIXES)
# =========================================================
RUN curl -L \
    https://github.com/yudai/gotty/releases/latest/download/gotty_linux_amd64 \
    -o /usr/local/bin/gotty && \
    chmod +x /usr/local/bin/gotty

# =========================================================
# FILE MANAGER (FULL ACCESS)
# =========================================================
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

# =========================================================
# SYSTEMCTL FIX (SAFE STUB FROM YOUR REQUEST)
# =========================================================
RUN echo -e '#!/bin/bash\necho "systemctl disabled in container mode"\nexit 0' > /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl

# =========================================================
# START SCRIPT (MIX OF ALL YOUR OLD IDEAS)
# =========================================================
RUN cat > /start.sh << 'EOF'
#!/bin/bash

echo "===================================="
echo " MIXED CENTOS VPS PANEL START"
echo "===================================="

# FIX DNS EVERY START (RAILWAY SAFE)
echo "nameserver 1.1.1.1" > /etc/resolv.conf || true
echo "nameserver 8.8.8.8" >> /etc/resolv.conf || true

mkdir -p /var/run/sshd

# START SSH
/usr/sbin/sshd || true
echo "SSH READY -> root/root"

# START FILE MANAGER
filebrowser -r / -p 8081 --no-auth &
echo "FILE ACCESS -> http://localhost:8081"

# START TERMINAL
/usr/local/bin/gotty -p 8080 bash &
echo "TERMINAL -> http://localhost:8080"

echo "ALL SYSTEMS RUNNING (MIXED FIX MODE)"

tail -f /dev/null
EOF

RUN chmod +x /start.sh

# =========================================================
# PORTS
# =========================================================
EXPOSE 22 8080 8081

CMD ["/start.sh"]
