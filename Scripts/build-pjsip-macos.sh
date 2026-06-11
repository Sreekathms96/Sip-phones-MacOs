#!/usr/bin/env bash
set -euo pipefail

PJSIP_VERSION="${PJSIP_VERSION:-2.14.1}"
PREFIX="${PREFIX:-${PWD}/pjsip}"
WORKDIR="${WORKDIR:-$PWD/.build/pjsip}"

mkdir -p "$WORKDIR"
cd "$WORKDIR"

if [ ! -d "pjproject-$PJSIP_VERSION" ]; then
  curl -L "https://github.com/pjsip/pjproject/archive/refs/tags/$PJSIP_VERSION.tar.gz" -o "pjproject-$PJSIP_VERSION.tar.gz"
  tar -xzf "pjproject-$PJSIP_VERSION.tar.gz"
fi

cd "pjproject-$PJSIP_VERSION"

cat > pjlib/include/pj/config_site.h <<'CONFIG'
#define PJ_CONFIG_DARWIN 1
#define PJMEDIA_HAS_VIDEO 0
#define PJ_HAS_SSL_SOCK 1
#define PJSIP_HAS_TLS_TRANSPORT 1
#define PJMEDIA_AUDIO_DEV_HAS_COREAUDIO 1
#define PJMEDIA_HAS_SRTP 1
#define PJMEDIA_HAS_WEBRTC_AEC 1
#include <pj/config_site_sample.h>
CONFIG

export OPENSSL_PREFIX="$(brew --prefix openssl@3)"

export CFLAGS="-arch arm64 -mmacosx-version-min=14.0 -I${OPENSSL_PREFIX}/include"
export CPPFLAGS="-I${OPENSSL_PREFIX}/include"
export LDFLAGS="-arch arm64 -mmacosx-version-min=14.0 -L${OPENSSL_PREFIX}/lib"

./configure \
  --prefix="$PREFIX" \
  --disable-video \
  --enable-shared=no \
  --with-ssl="${OPENSSL_PREFIX}"
make dep
make -j"$(sysctl -n hw.logicalcpu)"
make install

echo "PJSIP installed at $PREFIX"
