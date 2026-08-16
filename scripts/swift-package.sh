#!/bin/sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="$ROOT/.build"

swift_package() {
    swift package \
        --package-path "$ROOT" \
        --cache-path "$BUILD_DIR/package-cache" \
        --config-path "$BUILD_DIR/package-config" \
        --security-path "$BUILD_DIR/package-security" \
        --scratch-path "$BUILD_DIR" \
        --disable-keychain \
        --disable-netrc \
        "$@"
}

swift_command() {
    command=$1
    shift
    swift "$command" \
        --package-path "$ROOT" \
        --cache-path "$BUILD_DIR/package-cache" \
        --config-path "$BUILD_DIR/package-config" \
        --security-path "$BUILD_DIR/package-security" \
        --scratch-path "$BUILD_DIR" \
        --disable-keychain \
        --disable-netrc \
        "$@"
}

usage() {
    printf '%s\n' "Usage: scripts/swift-package.sh {resolve|build|test} [Swift options]"
}

if [ "$#" -lt 1 ]; then
    usage >&2
    exit 64
fi

command=$1
shift

case "$command" in
    resolve)
        swift_package resolve "$@"
        ;;
    build)
        swift_command "$command" \
            --only-use-versions-from-resolved-file \
            "$@"
        ;;
    test)
        swift_command build \
            --only-use-versions-from-resolved-file \
            --product EscutaCoreTests "$@"
        "$BUILD_DIR/arm64-apple-macosx/debug/EscutaCoreTests"
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
