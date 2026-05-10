FROM centos:7

ENV container=docker
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV SYSTEMD_IGNORE_CHROOT=1
ENV DEBIAN_FRONTEND=noninteractive

STOPSIGNAL SIGRTMIN+3

# =========================================================
# FIX OLD CENTOS 7 REPOSITORIES
# =========================================================
RUN rm -rf /etc/yum.repos.d/* && \
    curl -L \
    https://raw.githubusercontent.com/CentOS/sig-cloud-instance-images/CentOS-7/docker/centos-7.repo \
    -o /etc/yum.repos.d/CentOS-Base.repo || true

RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/* || true && \
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/* || true

RUN yum clean all && \
    yum makecache fast || true

RUN yum update -y || true

# =========================================================
# HUGE PACKAGE STACK
# =========================================================
RUN yum install -y \
    epel-release \
    sudo \
    curl \
    wget \
    git \
    nano \
    vim \
    zip \
    unzip \
    tar \
    gzip \
    bzip2 \
    xz \
    file \
    which \
    hostname \
    net-tools \
    iproute \
    iputils \
    bind-utils \
    traceroute \
    tcpdump \
    nmap \
    nmap-ncat \
    telnet \
    openssh-server \
    openssh-clients \
    passwd \
    procps-ng \
    psmisc \
    util-linux \
    rsync \
    lsof \
    screen \
    tmux \
    htop \
    tree \
    jq \
    socat \
    expect \
    dos2unix \
    cronie \
    crontabs \
    python3 \
    python3-pip \
    gcc \
    gcc-c++ \
    make \
    automake \
    autoconf \
    cmake \
    kernel-headers \
    kernel-devel \
    bash-completion \
    openssl \
    openssl-devel \
    ca-certificates \
    glibc \
    glibc-common \
    libstdc++ \
    ncurses \
    less \
    pciutils \
    usbutils \
    iptables \
    iptables-services \
    systemd \
    systemd-libs \
    systemd-sysv \
    dbus \
    dbus-x11 \
    dbus-daemon \
    rsyslog \
    kmod \
    policycoreutils \
    policycoreutils-python \
    initscripts || true

# =========================================================
# FIX UTF8 LOCALE
# =========================================================
RUN localedef -i en_US -f UTF-8 en_US.UTF-8 || true

# =========================================================
# FIX NETWORK + DNS
# =========================================================
RUN rm -f /etc/resolv.conf || true && \
    echo "nameserver 1.1.1.1" > /etc/resolv.conf && \
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf

# =========================================================
# FIX SSH SERVER
# =========================================================
RUN mkdir -p /var/run/sshd && \
    ssh-keygen -A

RUN echo "root:root" | chpasswd

RUN sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config || true && \
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config || true && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' /etc/ssh/sshd_config || true && \
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config || true && \
    echo "UseDNS no" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config

# =========================================================
# ENABLE SERVICES
# =========================================================
RUN systemctl enable sshd || true
RUN systemctl enable crond || true
RUN systemctl enable rsyslog || true
RUN systemctl enable dbus || true

# =========================================================
# CLEAN BROKEN SYSTEMD SERVICES
# =========================================================
RUN (cd /lib/systemd/system/sysinit.target.wants/; \
    for i in *; do \
        [ "$i" = "systemd-tmpfiles-setup.service" ] || rm -f "$i"; \
    done) && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/* && \
    rm -f /lib/systemd/system/anaconda.target.wants/*

# =========================================================
# SYSTEM LIMITS + SYSCTL
# =========================================================
RUN echo '* soft nofile 1048576' >> /etc/security/limits.conf && \
    echo '* hard nofile 1048576' >> /etc/security/limits.conf && \
    echo 'fs.file-max = 2097152' >> /etc/sysctl.conf && \
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf && \
    echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf && \
    echo 'net.ipv4.tcp_syncookies = 1' >> /etc/sysctl.conf

# =========================================================
# INSTALL SSHX
# =========================================================
RUN curl -sSf https://sshx.io/get | sh || true

# =========================================================
# STARTUP SCRIPT
# =========================================================
RUN cat > /usr/local/bin/container-start << 'EOF'
#!/bin/bash

clear

echo "========================================"
echo "   CENTOS 7 ULTRA STACKED CONTAINER"
echo "========================================"

mkdir -p /run/dbus
dbus-daemon --system --fork || true

mkdir -p /sys/fs/cgroup || true

echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

sysctl -p || true

ulimit -n 1048576 || true
ulimit -u unlimited || true

systemctl start dbus || true
systemctl start rsyslog || true
systemctl start crond || true
systemctl start sshd || true

echo "USER: root"
echo "PASS: root"

sshx run || bash
tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/container-start

# =========================================================
# EXPOSE PORTS
# =========================================================
EXPOSE 22

# =========================================================
# SYSTEMD SUPPORT (NO VOLUME BECAUSE RAILWAY BLOCKS IT)
# =========================================================

# =========================================================
# HEALTHCHECK
# =========================================================
HEALTHCHECK CMD ps aux | grep sshd || exit 1

CMD ["/usr/sbin/init"]
