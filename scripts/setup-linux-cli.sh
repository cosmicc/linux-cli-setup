#!/usr/bin/env bash
#
# Install common CLI tooling, selected profile packages, Fish shell, Fisher/Tide
# prompt configuration, and a dynamic login MOTD for the user who invoked sudo.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/linux-cli-common.sh
source "$SCRIPT_DIR/lib/linux-cli-common.sh"

show_help() {
    cat <<'HELP'
Usage: sudo ./install.sh [options]

Install the core Linux CLI setup and optional profiles.

Options:
  --profile NAME[,NAME]   Install one or more profiles in addition to core.
  --profiles NAME[,NAME]  Alias for --profile.
  --all-profiles          Install every profile.
  --list-profiles         Show available profiles.
  --debug                 Show captured installer output and debug details.
  --no-color              Disable colored console output.
  --version               Show version.
  --help                  Show this help.

Environment:
  TARGET_USER=username                 Use when running directly as root.
  LINUX_CLI_KEEP_DEFAULT_MOTD=1        Do not disable existing MOTD snippets.
  LINUX_CLI_DOCKER_APT_SOURCE=distro   Use distro Docker packages instead of Docker's official apt repo.
HELP
}

install_selected_profiles() {
    local profile

    for profile in "${SELECTED_PROFILES[@]}"; do
        if [[ "$profile" == "docker" ]]; then
            install_docker_profile
            continue
        fi

        install_profile_packages "$profile"

        if [[ "$profile" == "dev" ]]; then
            install_dev_tools
        fi
    done
}

main() {
    parse_profile_selection 1 "$@"

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

    require_root
    init_logging install
    start_transaction
    trap transaction_error_trap ERR
    init_runtime_context
    PACKAGE_STEP_VERB="Installing"
    export PACKAGE_STEP_VERB

    log "Detected package family: $PACKAGE_FAMILY"
    log "Target user: $TARGET_USER"
    log "Selected profiles: $(selected_profiles_csv)"

    update_package_database_and_system
    ensure_yay_on_arch
    install_selected_profiles
    install_jetbrains_nerd_font_from_package_or_release
    enable_openssh_service
    enable_arch_helpers
    configure_time_sync
    install_status_commands
    install_auto_update_service
    configure_git_defaults
    configure_fish_files
    install_fisher_plugins
    set_default_shell
    install_motd
    write_install_state "$(selected_profiles_csv)" "$ORIGINAL_SHELL"
    commit_transaction
    trap - ERR

    log "Setup complete. Open a new login session to see the Fish prompt and MOTD."
    if profile_is_selected docker; then
        log "Docker group membership takes effect after $TARGET_USER logs out and back in."
    fi
}

main "$@"
