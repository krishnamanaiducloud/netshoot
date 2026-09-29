ARG ALPINE_IMAGE=alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b
ARG GO_IMAGE=cgr.dev/chainguard/go:latest-dev@sha256:21b175db480c45f8edd504d1a9bf80cc15f6026b2f427b0c03822c00a9dbb95b

FROM ${GO_IMAGE} AS fetcher
USER root
COPY build/fetch_binaries.sh /tmp/fetch_binaries.sh
RUN sed -i 's/\r$//' /tmp/fetch_binaries.sh \
    && /tmp/fetch_binaries.sh \
    && rm -rf /root/go /root/.cache/go-build /tmp/grpcurl-src /tmp/fortio-src

FROM ${ALPINE_IMAGE}

ARG ALPINE_PACKAGE_REFRESH=2026-09-29
ARG OH_MY_ZSH_COMMIT=b54a71977574cfcf659cc2f15a5e6422f17a8da7
ARG ZSH_AUTOSUGGESTIONS_COMMIT=85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
ARG POWERLEVEL10K_COMMIT=3308262dfbd743b6e1d3956a2b5572f7a049d692

RUN set -ex \
    && echo "Refreshing Alpine packages for ${ALPINE_PACKAGE_REFRESH}" \
    && apk add --upgrade --no-cache \
    apache2-utils \
    bash \
    bind-tools \
    bird \
    bridge-utils \
    busybox-extras \
    conntrack-tools \
    curl \
    dhcping \
    drill \
    ethtool \
    file\
    fping \
    iftop \
    iperf \
    iperf3 \
    iproute2 \
    ipset \
    iptables \
    iptraf-ng \
    iputils \
    ipvsadm \
    httpie \
    jq \
    libc6-compat \
    liboping \
    ltrace \
    mtr \
    net-snmp-tools \
    netcat-openbsd \
    nftables \
    ngrep \
    nmap \
    nmap-nping \
    nmap-scripts \
    openssl \
    py3-pip \
    py3-setuptools \
    scapy \
    socat \
    speedtest-cli \
    openssh \
    strace \
    tcpdump \
    tcptraceroute \
    tshark \
    util-linux \
    vim \
    git \
    zsh \
    websocat \
    perl-crypt-ssleay \
    perl-net-ssleay \
    && apk add --upgrade --no-cache \
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
      --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing \
      apache2-utils \
      bind-tools \
      c-ares \
      libssh \
      swaks

# Installing grpcurl
COPY --from=fetcher /tmp/grpcurl /usr/local/bin/grpcurl

# Installing fortio
COPY --from=fetcher /tmp/fortio /usr/local/bin/fortio

# Setting User and Home
USER root
WORKDIR /root
ENV HOSTNAME=netshoot

# ZSH Themes
RUN set -eux; \
    mkdir -p \
      /root/.oh-my-zsh \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
      /root/.oh-my-zsh/custom/themes/powerlevel10k; \
    curl --fail --location --silent --show-error --retry 5 --retry-all-errors \
      --retry-delay 5 --connect-timeout 20 --max-time 300 \
      --output /tmp/oh-my-zsh.tar.gz \
      "https://github.com/ohmyzsh/ohmyzsh/archive/${OH_MY_ZSH_COMMIT}.tar.gz"; \
    tar -xzf /tmp/oh-my-zsh.tar.gz --strip-components=1 -C /root/.oh-my-zsh; \
    curl --fail --location --silent --show-error --retry 5 --retry-all-errors \
      --retry-delay 5 --connect-timeout 20 --max-time 300 \
      --output /tmp/zsh-autosuggestions.tar.gz \
      "https://github.com/zsh-users/zsh-autosuggestions/archive/${ZSH_AUTOSUGGESTIONS_COMMIT}.tar.gz"; \
    tar -xzf /tmp/zsh-autosuggestions.tar.gz --strip-components=1 \
      -C /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions; \
    curl --fail --location --silent --show-error --retry 5 --retry-all-errors \
      --retry-delay 5 --connect-timeout 20 --max-time 300 \
      --output /tmp/powerlevel10k.tar.gz \
      "https://github.com/romkatv/powerlevel10k/archive/${POWERLEVEL10K_COMMIT}.tar.gz"; \
    tar -xzf /tmp/powerlevel10k.tar.gz --strip-components=1 \
      -C /root/.oh-my-zsh/custom/themes/powerlevel10k; \
    for plugin in /root/.oh-my-zsh/plugins/*; do \
      case "$(basename "$plugin")" in \
        docker|git|jsontools|macports|node|sudo|web-search|yarn) ;; \
        *) rm -rf "$plugin" ;; \
      esac; \
    done; \
    rm -rf \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions/Gemfile.lock \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions/spec \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions/test \
      /tmp/oh-my-zsh.tar.gz \
      /tmp/zsh-autosuggestions.tar.gz \
      /tmp/powerlevel10k.tar.gz
COPY zshrc .zshrc
COPY motd motd

# Fix permissions for OpenShift and tshark
RUN chmod -R g=u /root \
    && chown root:root /usr/bin/dumpcap \
    && rm -rf /var/cache/apk/* /tmp/*

# Running ZSH
CMD ["zsh"]
