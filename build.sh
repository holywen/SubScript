#!/usr/bin/env bash
set -euo pipefail

COMMAND="${1:-all}"

case "$COMMAND" in
    build)
        make build
        ;;
    debug)
        make build BUILD_TYPE=debug
        ;;
    dmg)
        make dmg
        ;;
    rebuild-metal)
        make metallib
        ;;
    clean)
        make clean
        ;;
    setup)
        make setup
        ;;
    all)
        make all
        ;;
    *)
        echo "Usage: $0 {build|debug|dmg|rebuild-metal|clean|setup|all}"
        exit 1
        ;;
esac
