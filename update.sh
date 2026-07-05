#!/usr/bin/env bash
#
# Compatibility entry point. The installer now refreshes an existing
# linux-cli-setup installation when saved state is present.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export LINUX_CLI_ENTRYPOINT="$SCRIPT_DIR/install.sh"
exec "$SCRIPT_DIR/install.sh" "$@"
