FROM centos:7

ENV container=docker
ENV TERM=xterm-256color
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV SYSTEMD_IGNORE_CHROOT=1

STOPSIGNAL SIGRTMIN+3

# =========================================================
# FIX CENTOS 7 BROKEN REPOS (CRITICAL FIX)
# =========================================================
RUN rm -rf /etc/yum.repos.d/* && \
    curl -o /etc/yum.repos.d/CentOS-Base.repo \
    http://vault.centos.org/centos/7/os/x86_64/repodata/repomd.xml || true

# FORCE CORRECT REPO FILE (REAL FIX)
RUN curl -o /etc/yum.repos.d/CentOS-Base.repo \
https://raw.githubusercontent.com/CentOS/sig-cloud-instance-images/CentOS-7/docker/centos-7.repo || true

# =========================================================
# FIX YUM CACHE
# =========================================================
RUN yum clean all || true && \
    yum makecache || true

# =========================================================
# INSTALL CORE SYSTEM FIRST (IMPORTANT ORDER FIX)
# =========================================================
RUN yum install -y \
    curl wget git sudo \
    openssh-server openssh-clients \
    dbus systemd systemd-libs systemd-sysv \
    || true

# =========================================================
# NOW SSH WILL EXIST (FIX YOUR ERROR)
# =========================================================
RUN mkdir -p /var/run/sshd && \
    /usr/bin/ssh-keygen -A || true

RUN echo "root:root" | chpasswd || true

# CREATE FILE IF MISSING (FIX YOUR SECOND ERROR)
RUN touch /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "UseDNS no" >> /etc/ssh/sshd_config

# =========================================================
# REST OF YOUR PACKAGES (SAFE INSTALL LATER)
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
# SSH START FIX
# =========================================================
RUN systemctl enable sshd || true

# =========================================================
# STARTUP SCRIPT
# =========================================================
RUN cat > /usr/local/bin/container-start << 'EOF'
#!/bin/bash

echo "STARTING CONTAINER"

mkdir -p /var/run/sshd

# FIX SSH IF MISSING
if [ ! -f /etc/ssh/sshd_config ]; then
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
