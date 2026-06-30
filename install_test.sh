#!/usr/bin/env bash
#
# Non-mutating package availability diagnostics for linux-cli-setup.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export LINUX_CLI_ENTRYPOINT="$SCRIPT_DIR/install_test.sh"
exec "$SCRIPT_DIR/scripts/install-test-linux-cli.sh" "$@"
