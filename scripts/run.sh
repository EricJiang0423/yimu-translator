#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DIR=".build/direct"

if [ ! -x "$DIR/game-translator" ]; then
    echo "=== Building first ==="
    bash scripts/build-direct.sh
fi

echo "=== Starting ==="
exec "$DIR/game-translator"
