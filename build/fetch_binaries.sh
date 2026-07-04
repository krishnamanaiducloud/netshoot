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
  git clone --depth 1 --branch "v${VERSION}" https://github.com/bcicen/ctop.git /tmp/ctop-src
  (
    cd /tmp/ctop-src
    go get -u=patch .
    go mod edit \
      -require=github.com/fsouza/go-dockerclient@v1.13.2 \
      -require=github.com/containerd/containerd@v1.7.33 \
      -require=github.com/opencontainers/image-spec@v1.1.1 \
      -require=github.com/opencontainers/runtime-spec@v1.3.0 \
      -require=github.com/opencontainers/runc@v1.5.0 \
      -require=golang.org/x/crypto@v0.53.0 \
      -require=golang.org/x/net@v0.56.0 \
      -require=golang.org/x/sys@v0.46.0 \
      -require=golang.org/x/text@v0.38.0
    go mod download
    CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/ctop .
  )
  chmod +x /tmp/ctop
  chown root:root /tmp/ctop
}

get_calicoctl() {
  VERSION=$CALICOCTL_VERSION
  LINK="https://github.com/projectcalico/calico/releases/download/${VERSION}/calicoctl-linux-${ARCH}"
  wget "$LINK" -O /tmp/calicoctl && chmod +x /tmp/calicoctl
}

get_termshark() {
  VERSION=${TERMSHARK_VERSION#v}
  git clone --depth 1 --branch "v${VERSION}" https://github.com/gcla/termshark.git /tmp/termshark-src
  (
    cd /tmp/termshark-src
    go get -u=patch ./cmd/termshark
    go mod edit \
      -require=github.com/antchfx/xmlquery@v1.5.1 \
      -require=github.com/antchfx/xpath@v1.3.6 \
      -require=github.com/gin-gonic/gin@v1.12.0 \
      -require=github.com/sirupsen/logrus@v1.9.4 \
      -require=github.com/spf13/viper@v1.21.0 \
      -require=golang.org/x/crypto@v0.53.0 \
      -require=golang.org/x/net@v0.56.0 \
      -require=golang.org/x/sys@v0.46.0 \
      -require=golang.org/x/text@v0.38.0
    go mod download
    CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/termshark ./cmd/termshark
  )
  chmod +x /tmp/termshark
  chown root:root /tmp/termshark
}

get_grpcurl() {
  VERSION=${GRPCURL_VERSION#v}
  git clone --depth 1 --branch "v${VERSION}" https://github.com/fullstorydev/grpcurl.git /tmp/grpcurl-src
  (
    cd /tmp/grpcurl-src
    go get -u=patch ./cmd/grpcurl
    go mod edit \
      -require=google.golang.org/grpc@v1.79.3 \
      -require=google.golang.org/protobuf@v1.36.11 \
      -require=github.com/go-jose/go-jose/v4@v4.1.4 \
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
  git clone --depth 1 --branch "v${VERSION}" https://github.com/fortio/fortio.git /tmp/fortio-src
  (
    cd /tmp/fortio-src
    go get -u=patch .
    go mod edit -require=golang.org/x/image@v0.43.0
    go mod download
    CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/fortio .
  )
  chmod +x /tmp/fortio
  chown root:root /tmp/fortio
}


get_ctop
get_calicoctl
get_termshark
get_grpcurl
get_fortio

