FROM centos:7

ENV container=docker
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV SYSTEMD_IGNORE_CHROOT=1

STOPSIGNAL SIGRTMIN+3

# =========================================================
# FIX CENTOS 7 REPO
# =========================================================
RUN rm -rf /etc/yum.repos.d/* && \
    curl -o /etc/yum.repos.d/CentOS-Base.repo \
    https://raw.githubusercontent.com/CentOS/sig-cloud-instance-images/CentOS-7/docker/centos-7.repo

# =========================================================
# YUM CACHE FIX
# =========================================================
RUN yum clean all || true && \
    yum makecache || true

# =========================================================
# CORE PACKAGES
# =========================================================
RUN yum install -y \
    curl wget git sudo \
    openssh-server openssh-clients \
    dbus systemd systemd-libs systemd-sysv \
    nano vim zip unzip tar gzip \
    net-tools iproute iputils \
    procps-ng psmisc util-linux \
    htop jq screen tmux \
    python3 python3-pip \
    gcc gcc-c++ make \
    || true

# =========================================================
# FIX SSH
# =========================================================
RUN mkdir -p /var/run/sshd || true

RUN if [ -f /usr/bin/ssh-keygen ]; then \
        /usr/bin/ssh-keygen -A; \
    fi

RUN echo "root:root" | chpasswd || true

RUN mkdir -p /etc/ssh && \
    touch /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "UseDNS no" >> /etc/ssh/sshd_config

# =========================================================
# INSTALL SSHX + SHOW IN BUILD LOGS
# =========================================================
RUN echo "===============================" && \
    echo "INSTALLING SSHX..." && \
    curl -sSf https://sshx.io/get | sh && \
    echo "SSHX INSTALL COMPLETE" && \
    (sshx --version || echo "SSHX INSTALLED BUT VERSION CHECK FAILED") && \
    echo "==============================="

# =========================================================
# START SCRIPT
# =========================================================
RUN cat > /usr/local/bin/container-start << 'EOF'
#!/bin/bash

echo "=================================="
echo " STARTING CONTAINER"
echo "=================================="

mkdir -p /var/run/sshd

/usr/sbin/sshd || echo "SSH FAILED"

echo "ROOT LOGIN: root/root"

# START SSHX AT RUNTIME
echo "STARTING SSHX..."
if command -v sshx >/dev/null 2>&1; then
    sshx run &
    echo "SSHX STARTED"
else
    echo "SSHX NOT FOUND"
fi

tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/container-start

EXPOSE 22

CMD ["/usr/local/bin/container-start"]
