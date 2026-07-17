#!/usr/bin/env bash
#
# Non-destructive update entry point for an existing linux-cli-setup install.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat <<'USAGE'
Usage: sudo ./update.sh [options]

Update an existing linux-cli-setup installation while preserving existing
configuration files. Run install.sh first on systems without saved install state.

Options:
  --profile NAME[,NAME]   Add one or more groups while updating saved groups.
  --profiles NAME[,NAME]  Alias for --profile.
  --all-profiles          Update every supported group.
  --skip-performance      Skip the default performance tuning section.
  --skip-hardening        Skip the default hardening section.
  --motd MODE             MOTD behavior: keep, replace, or combine.
  --list-profiles         Show available groups.
  --debug                 Show captured installer output and debug details.
  --no-color              Disable colored console output.
  --version               Show version.
  --help                  Show this help.

If no group option is provided, update.sh updates the previously installed
profiles. Existing configuration files are preserved and missing configuration
files are installed.
USAGE
}

for argument in "$@"; do
    if [[ "$argument" == "--help" ]]; then
        show_help
        exit 0
    fi
done

export LINUX_CLI_OPERATION=update
export LINUX_CLI_ENTRYPOINT="$SCRIPT_DIR/update.sh"
exec "$SCRIPT_DIR/scripts/setup-linux-cli.sh" "$@"
