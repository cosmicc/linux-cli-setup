#!/usr/bin/env bash
#
# Entry point for refreshing a linux-cli-setup installation.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export LINUX_CLI_ENTRYPOINT="$SCRIPT_DIR/update.sh"
exec "$SCRIPT_DIR/scripts/update-linux-cli.sh" "$@"
