#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${TMPDIR%/}/naivevpn-libbox-build"
SING_BOX_DIR="$BUILD_ROOT/sing-box"
GO_BIN="$(go env GOBIN)"
if [[ -z "$GO_BIN" ]]; then
  GO_BIN="$(go env GOPATH)/bin"
fi

export GOBIN="$GO_BIN"
export PATH="$GO_BIN:$PATH"

rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"

git clone --depth 1 https://github.com/SagerNet/sing-box.git "$SING_BOX_DIR"

pushd "$SING_BOX_DIR" >/dev/null
go install -v github.com/sagernet/gomobile/cmd/gomobile@v0.1.12
go install -v github.com/sagernet/gomobile/cmd/gobind@v0.1.12
"$GO_BIN/gomobile" init
go run ./cmd/internal/build_libbox -target apple -platform ios,iossimulator
popd >/dev/null

rm -rf "$ROOT_DIR/Libbox.xcframework"
cp -R "$SING_BOX_DIR/Libbox.xcframework" "$ROOT_DIR/Libbox.xcframework"

echo "Libbox.xcframework was copied to $ROOT_DIR/Libbox.xcframework"
