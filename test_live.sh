#!/bin/bash
# test_live.sh — run the skink-mongo live integration test against a
# real MongoDB server in a podman container.
#
#   ./test_live.sh                      # start mongo:7, run, stop
#   SKINK_MONGO_DSN=... ./test_live.sh  # against an existing server
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${MONGO_IMAGE:-docker.io/library/mongo:7}"
PORT="${MONGO_PORT:-17017}"
DSN="${SKINK_MONGO_DSN:-}"
CONTAINER=""

SKINK_HOME="${SKINK_HOME:-$HOME/.local/skink/std}"
SKINK_BIN="${SKINK:-$(command -v skink || echo "$HOME/.local/skink/bin/skink")}"

cleanup() {
    [ -n "$CONTAINER" ] && podman rm -f "$CONTAINER" >/dev/null 2>&1
    rm -f "$SCRIPT_DIR/.live_test_bin"
}
trap cleanup EXIT

if [ -z "$DSN" ]; then
    if ! command -v podman >/dev/null 2>&1; then
        echo "SKIP: podman not available and SKINK_MONGO_DSN unset"
        exit 0
    fi
    CONTAINER=$(podman run -d --rm \
        -e MONGO_INITDB_ROOT_USERNAME=skink \
        -e MONGO_INITDB_ROOT_PASSWORD=skinktest \
        -e MONGO_INITDB_DATABASE=skinkdb \
        -p "127.0.0.1:$PORT:27017" "$IMAGE")
    echo "started mongo container $CONTAINER on :$PORT"
    # Wait for readiness via a TCP probe.
    for i in $(seq 1 90); do
        if podman exec "$CONTAINER" mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
            break
        fi
        sleep 1
    done
    sleep 1
    DSN="mongodb://skink:skinktest@127.0.0.1:$PORT/skinkdb?authSource=admin"
fi

SKINK_HOME="$SKINK_HOME" "$SKINK_BIN" -o "$SCRIPT_DIR/.live_test_bin" "$SCRIPT_DIR/live_test.skink" || exit 1
SKINK_MONGO_DSN="$DSN" "$SCRIPT_DIR/.live_test_bin"
