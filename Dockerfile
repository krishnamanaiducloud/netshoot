ARG ALPINE_IMAGE=alpine:3.24.1@sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b
ARG GO_IMAGE=cgr.dev/chainguard/go:latest-dev
ARG RUST_IMAGE=cgr.dev/chainguard/rust:latest-dev

FROM ${GO_IMAGE} AS fetcher
USER root
COPY build/fetch_binaries.sh /tmp/fetch_binaries.sh
RUN sed -i 's/\r$//' /tmp/fetch_binaries.sh

RUN apk upgrade --no-cache \
  && apk add --upgrade --no-cache \
    bash \
    ca-certificates \
    curl \
    git \
    tar \
    wget

RUN /tmp/fetch_binaries.sh

FROM ${RUST_IMAGE} AS trippy-builder
ARG TRIPPY_VERSION=0.13.0

USER root

RUN apk upgrade --no-cache \
  && apk add --upgrade --no-cache \
    build-base \
    git

WORKDIR /src
COPY build/trippy-maxminddb-0.29.patch /tmp/trippy-maxminddb-0.29.patch
RUN --mount=type=cache,id=netshoot-cargo-registry,target=/usr/local/cargo/registry,sharing=locked \
    --mount=type=cache,id=netshoot-cargo-git,target=/usr/local/cargo/git,sharing=locked \
    --mount=type=cache,id=netshoot-trippy-target,target=/src/target,sharing=locked \
    git init . \
    && git remote add origin https://github.com/fujiapple852/trippy.git \
    && git fetch --depth 1 origin "refs/tags/${TRIPPY_VERSION}" \
    && git checkout --detach FETCH_HEAD \
    && git apply /tmp/trippy-maxminddb-0.29.patch \
    && sed -i 's/maxminddb = "0.25.0"/maxminddb = "0.29.0"/' Cargo.toml \
    && cargo update -p rand@0.9.1 --precise 0.9.4 \
    && cargo update -p maxminddb --precise 0.29.0 \
    && cargo build --release --bin trip \
    && install -Dm755 target/release/trip /out/trip

FROM ${ALPINE_IMAGE}

ARG OH_MY_ZSH_COMMIT=ff2f16e8df7386d7198009566aef09cbbc0c8212
ARG ZSH_AUTOSUGGESTIONS_COMMIT=85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5
ARG POWERLEVEL10K_COMMIT=9253fb1c5034410c43a0c681ff8294181c54016c

RUN set -ex \
    && apk upgrade --no-cache \
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

# Installing trippy
COPY --from=trippy-builder /out/trip /usr/local/bin/trip
RUN ln -s /usr/local/bin/trip /usr/local/bin/trippy

# Installing calicoctl
COPY --from=fetcher /tmp/calicoctl /usr/local/bin/calicoctl

# Installing grpcurl
COPY --from=fetcher /tmp/grpcurl /usr/local/bin/grpcurl

# Installing fortio
COPY --from=fetcher /tmp/fortio /usr/local/bin/fortio

# Installing termshark
COPY --from=fetcher /tmp/termshark /usr/local/bin/termshark

# Setting User and Home
USER root
WORKDIR /root
ENV HOSTNAME=netshoot

# ZSH Themes
RUN set -eux; \
    git init /root/.oh-my-zsh; \
    cd /root/.oh-my-zsh; \
    git remote add origin https://github.com/ohmyzsh/ohmyzsh.git; \
    git fetch --depth=1 origin "${OH_MY_ZSH_COMMIT}"; \
    git checkout --detach FETCH_HEAD; \
    rm -rf .git; \
    git init /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions; \
    cd /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions; \
    git remote add origin https://github.com/zsh-users/zsh-autosuggestions.git; \
    git fetch --depth=1 origin "${ZSH_AUTOSUGGESTIONS_COMMIT}"; \
    git checkout --detach FETCH_HEAD; \
    rm -rf .git; \
    git init /root/.oh-my-zsh/custom/themes/powerlevel10k; \
    cd /root/.oh-my-zsh/custom/themes/powerlevel10k; \
    git remote add origin https://github.com/romkatv/powerlevel10k.git; \
    git fetch --depth=1 origin "${POWERLEVEL10K_COMMIT}"; \
    git checkout --detach FETCH_HEAD; \
    rm -rf .git; \
    for plugin in /root/.oh-my-zsh/plugins/*; do \
      case "$(basename "$plugin")" in \
        docker|git|jsontools|macports|node|sudo|web-search|yarn) ;; \
        *) rm -rf "$plugin" ;; \
      esac; \
    done; \
    rm -rf \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions/Gemfile.lock \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions/spec \
      /root/.oh-my-zsh/custom/plugins/zsh-autosuggestions/test
COPY zshrc .zshrc
COPY motd motd

# Fix permissions for OpenShift and tshark
RUN chmod -R g=u /root \
    && chown root:root /usr/bin/dumpcap \
    && rm -rf /var/cache/apk/* /tmp/*

# Running ZSH
CMD ["zsh"]
