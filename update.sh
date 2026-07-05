#!/usr/bin/env bash
#
# Compatibility entry point. The installer now refreshes an existing
# linux-cli-setup installation when saved state is present.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat <<'USAGE'
Usage: sudo ./update.sh [options]

Compatibility entry point. This runs install.sh, which refreshes an existing
linux-cli-setup installation when saved state is present.

Options:
  --profile NAME[,NAME]   Refresh one or more groups in addition to core.
  --profiles NAME[,NAME]  Alias for --profile.
  --all-profiles          Refresh every supported group.
  --list-profiles         Show available groups.
  --debug                 Show captured installer output and debug details.
  --no-color              Disable colored console output.
  --version               Show version.
  --help                  Show this help.

If no group option is provided and saved install state exists, install.sh
refreshes the previously installed profiles. On a new system, install.sh
installs core only unless more profiles are specified.
USAGE
}

for argument in "$@"; do
    if [[ "$argument" == "--help" ]]; then
        show_help
        exit 0
    fi
done

export LINUX_CLI_ENTRYPOINT="$SCRIPT_DIR/install.sh"
exec "$SCRIPT_DIR/install.sh" "$@"
