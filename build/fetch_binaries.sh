#!/usr/bin/env bash
set -euo pipefail

CALICOCTL_VERSION="${CALICOCTL_VERSION:-v3.32.1}"
GRPCURL_VERSION="${GRPCURL_VERSION:-1.9.3}"
FORTIO_VERSION="${FORTIO_VERSION:-1.75.2}"

export GOPROXY="${GOPROXY:-https://proxy.golang.org|direct}"
export GOSUMDB="${GOSUMDB:-sum.golang.org}"

retry() {
  attempts=5
  delay=5
  count=1

  until "$@"; do
    if [ "$count" -ge "$attempts" ]; then
      return 1
    fi

    echo "Command failed. Retrying in ${delay}s: $*" >&2
    sleep "$delay"
    count=$((count + 1))
    delay=$((delay * 2))
  done
}

clone_repo() {
  repo=$1
  tag=$2
  dest=$3

  rm -rf "$dest"
  git clone --depth 1 --branch "$tag" "$repo" "$dest"
}

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
  retry wget "$LINK" -O /tmp/calicoctl && chmod +x /tmp/calicoctl
}

get_grpcurl() {
  VERSION=${GRPCURL_VERSION#v}
  retry clone_repo https://github.com/fullstorydev/grpcurl.git "v${VERSION}" /tmp/grpcurl-src
  (
    cd /tmp/grpcurl-src
    retry go get -u=patch ./cmd/grpcurl
    go mod edit \
      -require=google.golang.org/grpc@v1.82.0 \
      -require=google.golang.org/protobuf@v1.36.11 \
      -require=github.com/go-jose/go-jose/v4@v4.1.4 \
      -require=golang.org/x/crypto@v0.53.0 \
      -require=golang.org/x/net@v0.56.0 \
      -require=golang.org/x/sys@v0.46.0 \
      -require=golang.org/x/text@v0.38.0
    retry go mod download
    retry env CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/grpcurl ./cmd/grpcurl
  )
  chmod +x /tmp/grpcurl
  chown root:root /tmp/grpcurl
}

get_fortio() {
  VERSION=${FORTIO_VERSION#v}
  retry clone_repo https://github.com/fortio/fortio.git "v${VERSION}" /tmp/fortio-src
  (
    cd /tmp/fortio-src
    retry go get -u=patch .
    go mod edit -require=golang.org/x/image@v0.43.0
    retry go mod download
    retry env CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/fortio .
  )
  chmod +x /tmp/fortio
  chown root:root /tmp/fortio
}


get_calicoctl
get_grpcurl
get_fortio

