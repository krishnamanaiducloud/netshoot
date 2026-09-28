#!/usr/bin/env bash
set -euo pipefail

GRPCURL_VERSION="${GRPCURL_VERSION:-1.9.4}"
FORTIO_VERSION="${FORTIO_VERSION:-1.75.3}"

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
  timeout 180 git \
    -c http.lowSpeedLimit=1024 \
    -c http.lowSpeedTime=60 \
    clone --depth 1 --branch "$tag" "$repo" "$dest"
}

build_grpcurl() {
  retry clone_repo \
    https://github.com/fullstorydev/grpcurl.git \
    "v${GRPCURL_VERSION#v}" \
    /tmp/grpcurl-src

  (
    cd /tmp/grpcurl-src
    retry timeout 600 go get -u=patch ./cmd/grpcurl
    go mod edit \
      -require=google.golang.org/grpc@v1.83.2 \
      -require=google.golang.org/protobuf@v1.36.12 \
      -require=github.com/go-jose/go-jose/v4@v4.1.5 \
      -require=golang.org/x/crypto@v0.56.0 \
      -require=golang.org/x/net@v0.59.0 \
      -require=golang.org/x/sys@v0.48.0 \
      -require=golang.org/x/text@v0.42.0
    retry timeout 600 go mod download
    retry timeout 600 env CGO_ENABLED=0 go build \
      -mod=mod -trimpath \
      -ldflags="-s -w -buildid= -X main.version=${GRPCURL_VERSION#v}" \
      -o /tmp/grpcurl ./cmd/grpcurl
  )
}

build_fortio() {
  retry clone_repo \
    https://github.com/fortio/fortio.git \
    "v${FORTIO_VERSION#v}" \
    /tmp/fortio-src

  (
    cd /tmp/fortio-src
    retry timeout 600 go get -u=patch .
    go mod edit \
      -require=golang.org/x/image@v0.45.0 \
      -require=golang.org/x/crypto@v0.56.0 \
      -require=google.golang.org/grpc@v1.83.2 \
      -require=golang.org/x/text@v0.42.0
    retry timeout 600 go mod download
    git update-index --assume-unchanged go.mod go.sum
    retry timeout 600 env CGO_ENABLED=0 go build \
      -mod=mod -trimpath -ldflags="-s -w -buildid=" \
      -o /tmp/fortio .
  )
}

build_grpcurl
build_fortio
chmod 0755 /tmp/grpcurl /tmp/fortio
chown root:root /tmp/grpcurl /tmp/fortio
