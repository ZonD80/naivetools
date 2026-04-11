#!/usr/bin/env bash
# Re-flatten an existing Libbox.xcframework (e.g. after pulling without rebuilding).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCFW="${1:-$ROOT_DIR/Libbox.xcframework}"
# shellcheck source=libbox_flatten_framework.sh
source "$(dirname "$0")/libbox_flatten_framework.sh"
[[ -d "$XCFW" ]] || { echo "Not a directory: $XCFW" >&2; exit 1; }
flatten_libbox_xcframework_at "$XCFW"
echo "Flattened frameworks under $XCFW"
