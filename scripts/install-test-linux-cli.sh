#!/usr/bin/env bash
#
# Check whether packages from linux-cli-setup package groups are available on
# the current system without installing or removing anything.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/linux-cli-common.sh
source "$SCRIPT_DIR/lib/linux-cli-common.sh"

show_help() {
    cat <<'HELP'
Usage: ./install_test.sh [options]

Check whether linux-cli-setup package groups are available on this system.

Options:
  --profile NAME[,NAME]   Check one or more package groups.
  --profiles NAME[,NAME]  Alias for --profile.
  --all-profiles          Check every supported group. This is the default.
  --list-profiles         Show available groups.
  --debug                 Show command details.
  --no-color              Disable colored console output.
  --version               Show version.
  --help                  Show this help.

The script reads data/package-groups.tsv and does not install, update, remove,
or enable anything.
HELP
}

main() {
    parse_profile_selection 0 "$@"

    if [[ "${#PROFILE_POSITIONAL_ARGS[@]}" -gt 0 ]]; then
        case "${PROFILE_POSITIONAL_ARGS[0]}" in
            --help)
                show_help
                exit 0
                ;;
            --version)
                print_version
                exit 0
                ;;
            *)
                die "Unknown argument: ${PROFILE_POSITIONAL_ARGS[0]}"
                ;;
        esac
    fi

    if [[ "${#SELECTED_PROFILES[@]}" -eq 0 ]]; then
        SELECTED_PROFILES=("${SUPPORTED_PROFILES[@]}")
    fi

    init_logging_with_user_fallback install-test
    init_package_family

    log "Detected package family: $PACKAGE_FAMILY"
    log "Checking profiles: $(selected_profiles_csv)"

    if test_package_availability_for_profiles; then
        exit 0
    fi

    exit 1
}

main "$@"
