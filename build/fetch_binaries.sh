#!/usr/bin/env bash
set -euo pipefail

CALICOCTL_VERSION="${CALICOCTL_VERSION:-v3.32.1}"
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

get_calicoctl() {
  VERSION=$CALICOCTL_VERSION
  LINK="https://github.com/projectcalico/calico/releases/download/${VERSION}/calicoctl-linux-${ARCH}"
  wget "$LINK" -O /tmp/calicoctl && chmod +x /tmp/calicoctl
}

get_grpcurl() {
  VERSION=${GRPCURL_VERSION#v}
  git clone --depth 1 --branch "v${VERSION}" https://github.com/fullstorydev/grpcurl.git /tmp/grpcurl-src
  (
    cd /tmp/grpcurl-src
    go mod edit \
      -require=google.golang.org/grpc@v1.79.3 \
      -require=google.golang.org/protobuf@v1.36.11 \
      -require=golang.org/x/net@v0.56.0 \
      -require=golang.org/x/sys@v0.46.0 \
      -require=golang.org/x/text@v0.38.0
    go mod download
    CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/grpcurl ./cmd/grpcurl
  )
  chmod +x /tmp/grpcurl
  chown root:root /tmp/grpcurl
}

get_fortio() {
  VERSION=${FORTIO_VERSION#v}
  CGO_ENABLED=0 GOBIN=/tmp go install -trimpath -ldflags="-s -w -buildid=" "fortio.org/fortio@v${VERSION}"
  chmod +x /tmp/fortio
  chown root:root /tmp/fortio
}


get_calicoctl
get_grpcurl
get_fortio

