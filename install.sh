#!/usr/bin/env bash
#
# Entry point for Linux CLI setup. Keep implementation details in scripts/ so
# templates and helper scripts remain easy to inspect and test.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export LINUX_CLI_OPERATION=install
export LINUX_CLI_ENTRYPOINT="$SCRIPT_DIR/install.sh"
exec "$SCRIPT_DIR/scripts/setup-linux-cli.sh" "$@"
