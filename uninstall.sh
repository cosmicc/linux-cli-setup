#!/usr/bin/env bash
#
# Entry point for removing linux-cli-setup managed files.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export LINUX_CLI_ENTRYPOINT="$SCRIPT_DIR/uninstall.sh"
exec "$SCRIPT_DIR/scripts/uninstall-linux-cli.sh" "$@"
