#!/usr/bin/env bash
set -euo pipefail

CTOP_VERSION="${CTOP_VERSION:-0.7.7}"
CALICOCTL_VERSION="${CALICOCTL_VERSION:-v3.32.1}"
TERMSHARK_VERSION="${TERMSHARK_VERSION:-2.4.0}"
GRPCURL_VERSION="${GRPCURL_VERSION:-1.9.3}"
FORTIO_VERSION="${FORTIO_VERSION:-1.75.2}"

ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH=amd64
        ;;
    aarch64)
        ARCH=arm64
        ;;
esac

get_ctop() {
  VERSION=${CTOP_VERSION#v}
  LINK="https://github.com/bcicen/ctop/releases/download/v${VERSION}/ctop-${VERSION}-linux-${ARCH}"
  wget "$LINK" -O /tmp/ctop && chmod +x /tmp/ctop
}

get_calicoctl() {
  VERSION=$CALICOCTL_VERSION
  LINK="https://github.com/projectcalico/calico/releases/download/${VERSION}/calicoctl-linux-${ARCH}"
  wget "$LINK" -O /tmp/calicoctl && chmod +x /tmp/calicoctl
}

get_termshark() {
  case "$ARCH" in
    *)
      VERSION=${TERMSHARK_VERSION#v}
      if [ "$ARCH" == "amd64" ]; then
        TERM_ARCH=x64
      else
        TERM_ARCH="$ARCH"
      fi
      LINK="https://github.com/gcla/termshark/releases/download/v${VERSION}/termshark_${VERSION}_linux_${TERM_ARCH}.tar.gz"
      wget "$LINK" -O /tmp/termshark.tar.gz && \
      tar -zxvf /tmp/termshark.tar.gz && \
      mv "termshark_${VERSION}_linux_${TERM_ARCH}/termshark" /tmp/termshark && \
      chmod +x /tmp/termshark
      ;;
  esac
}

get_grpcurl() {
  if [ "$ARCH" == "amd64" ]; then
    TERM_ARCH=x86_64
  else
    TERM_ARCH="$ARCH"
  fi
  VERSION=${GRPCURL_VERSION#v}
  LINK="https://github.com/fullstorydev/grpcurl/releases/download/v${VERSION}/grpcurl_${VERSION}_linux_${TERM_ARCH}.tar.gz"
  wget "$LINK" -O /tmp/grpcurl.tar.gz  && \
  tar --no-same-owner -zxvf /tmp/grpcurl.tar.gz && \
  mv "grpcurl" /tmp/grpcurl && \
  chmod +x /tmp/grpcurl
  chown root:root /tmp/grpcurl
}

get_fortio() {
  if [ "$ARCH" == "amd64" ]; then
    TERM_ARCH=x86_64
  else
    TERM_ARCH="$ARCH"
  fi
  VERSION=${FORTIO_VERSION#v}
  LINK="https://github.com/fortio/fortio/releases/download/v${VERSION}/fortio-linux_${ARCH}-${VERSION}.tgz"
  wget "$LINK" -O /tmp/fortio.tgz  && \
  tar -zxvf /tmp/fortio.tgz && \
  mv "usr/bin/fortio" /tmp/fortio && \
  chmod +x /tmp/fortio
}


get_ctop
get_calicoctl
get_termshark
get_grpcurl
get_fortio

