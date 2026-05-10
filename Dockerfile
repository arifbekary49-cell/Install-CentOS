FROM centos:7

ENV container=docker
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV SYSTEMD_IGNORE_CHROOT=1

STOPSIGNAL SIGRTMIN+3

# =========================================================
# FIX CENTOS 7 REPO (CRITICAL FIX - REAL REPO FILE)
# =========================================================
RUN rm -rf /etc/yum.repos.d/* && \
    curl -o /etc/yum.repos.d/CentOS-Base.repo \
    https://raw.githubusercontent.com/CentOS/sig-cloud-instance-images/CentOS-7/docker/centos-7.repo

# =========================================================
# FIX YUM CACHE
# =========================================================
RUN yum clean all || true && \
    yum makecache || true

# =========================================================
# INSTALL CORE PACKAGES FIRST (IMPORTANT ORDER FIX)
# =========================================================
RUN yum install -y \
    curl wget git sudo \
    openssh-server openssh-clients \
    dbus systemd systemd-libs systemd-sysv \
    || true

# =========================================================
# FIX SSH (SAFE GUARANTEED)
# =========================================================
RUN mkdir -p /var/run/sshd || true

# FIX ssh-keygen PATH ISSUE
RUN if [ -f /usr/bin/ssh-keygen ]; then \
        /usr/bin/ssh-keygen -A; \
    else \
        echo "ssh-keygen missing but continuing"; \
    fi

RUN echo "root:root" | chpasswd || true

# =========================================================
# FIX sshd_config (CREATE IF MISSING)
# =========================================================
RUN mkdir -p /etc/ssh || true && \
    touch /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "UseDNS no" >> /etc/ssh/sshd_config

# =========================================================
# REST OF YOUR PACKAGES
# =========================================================
RUN yum install -y \
    nano vim zip unzip tar gzip \
    net-tools iproute iputils \
    procps-ng psmisc util-linux \
    htop jq screen tmux \
    python3 python3-pip \
    gcc gcc-c++ make \
    || true

# =========================================================
# STARTUP SCRIPT
# =========================================================
RUN cat > /usr/local/bin/container-start << 'EOF'
#!/bin/bash

echo "STARTING CONTAINER"

mkdir -p /var/run/sshd

if [ ! -f /etc/ssh/sshd_config ]; then
    mkdir -p /etc/ssh
    touch /etc/ssh/sshd_config
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
fi

/usr/sbin/sshd || true

echo "ROOT LOGIN: root/root"

tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/container-start

EXPOSE 22

CMD ["/usr/local/bin/container-start"]
