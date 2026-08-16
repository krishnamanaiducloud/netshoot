#!/usr/bin/env bash
set -euo pipefail

CALICOCTL_VERSION="${CALICOCTL_VERSION:-v3.32.1}"
GRPCURL_VERSION="${GRPCURL_VERSION:-1.9.3}"
FORTIO_VERSION="${FORTIO_VERSION:-1.75.2}"
TERMSHARK_VERSION="${TERMSHARK_VERSION:-2.4.0}"

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
  retry clone_repo https://github.com/projectcalico/calico.git "${VERSION}" /tmp/calico-src
  (
    cd /tmp/calico-src
    retry go get -u=patch ./calicoctl/calicoctl
    go mod edit \
      -require=google.golang.org/grpc@v1.82.1 \
      -require=golang.org/x/text@v0.39.0
    retry go mod download
    # Dependency refreshes intentionally dirty the tagged checkout. Disable VCS
    # stamping so scanners do not mistake the resulting pseudo-version for an
    # ancient Calico release; the application version remains CALICOCTL_VERSION.
    retry env CGO_ENABLED=0 go build -mod=mod -buildvcs=false -trimpath -ldflags="-s -w -buildid=" -o /tmp/calicoctl ./calicoctl/calicoctl
  )
  chmod +x /tmp/calicoctl
  chown root:root /tmp/calicoctl
}

get_grpcurl() {
  VERSION=${GRPCURL_VERSION#v}
  retry clone_repo https://github.com/fullstorydev/grpcurl.git "v${VERSION}" /tmp/grpcurl-src
  (
    cd /tmp/grpcurl-src
    retry go get -u=patch ./cmd/grpcurl
    go mod edit \
      -require=google.golang.org/grpc@v1.82.1 \
      -require=google.golang.org/protobuf@v1.36.11 \
      -require=github.com/go-jose/go-jose/v4@v4.1.4 \
      -require=golang.org/x/crypto@v0.53.0 \
      -require=golang.org/x/net@v0.56.0 \
      -require=golang.org/x/sys@v0.46.0 \
      -require=golang.org/x/text@v0.39.0
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
    go mod edit \
      -require=golang.org/x/image@v0.43.0 \
      -require=google.golang.org/grpc@v1.82.1 \
      -require=golang.org/x/text@v0.39.0
    retry go mod download
    retry env CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/fortio .
  )
  chmod +x /tmp/fortio
  chown root:root /tmp/fortio
}

get_termshark() {
  VERSION=${TERMSHARK_VERSION#v}
  retry clone_repo https://github.com/gcla/termshark.git "v${VERSION}" /tmp/termshark-src
  (
    cd /tmp/termshark-src
    retry go get -u=patch ./cmd/termshark
    go mod edit \
      -require=github.com/antchfx/xmlquery@v1.5.1 \
      -require=github.com/antchfx/xpath@v1.3.6 \
      -require=github.com/sirupsen/logrus@v1.9.4 \
      -require=golang.org/x/crypto@v0.53.0 \
      -require=golang.org/x/net@v0.56.0 \
      -require=golang.org/x/sys@v0.46.0 \
      -require=golang.org/x/text@v0.39.0 \
      -require=gopkg.in/yaml.v3@v3.0.1
    retry go mod download
    retry env CGO_ENABLED=0 go build -mod=mod -trimpath -ldflags="-s -w -buildid=" -o /tmp/termshark ./cmd/termshark
  )
  chmod +x /tmp/termshark
  chown root:root /tmp/termshark
}


get_calicoctl
get_grpcurl
get_fortio
get_termshark

