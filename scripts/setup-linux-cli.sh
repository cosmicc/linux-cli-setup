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

Install the core Linux CLI setup and optional package groups.

Options:
  --profile NAME[,NAME]   Install one or more groups in addition to core.
  --profiles NAME[,NAME]  Alias for --profile.
  --all-profiles          Install every supported group.
  --list-profiles         Show available groups.
  --debug                 Show captured installer output and debug details.
  --no-color              Disable colored console output.
  --version               Show version.
  --help                  Show this help.

Environment:
  TARGET_USER=username                 Use when running directly as root.
  LINUX_CLI_KEEP_DEFAULT_MOTD=1        Do not disable existing MOTD snippets.
  LINUX_CLI_DOCKER_APT_SOURCE=distro   Use distro Docker packages instead of Docker's official apt repo.

If no group option is provided and the script is running in an interactive
terminal, install asks which optional groups to add. Core is always installed.
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

        if [[ "$profile" == "comfort" ]]; then
            install_comfort_tools
        fi

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
    self_update_if_newer "${LINUX_CLI_ENTRYPOINT:-$0}" "$@"
    start_transaction
    trap transaction_error_trap ERR
    init_runtime_context
    PACKAGE_STEP_VERB="Installing"
    export PACKAGE_STEP_VERB
    prompt_for_install_profiles

    log "Detected package family: $PACKAGE_FAMILY"
    log "Target user: $TARGET_USER"
    log "Selected profiles: $(selected_profiles_csv)"

    update_package_database_and_system
    ensure_yay_on_arch
    install_selected_profiles
    install_jetbrains_nerd_font_from_package_or_release
    enable_openssh_service
    configure_ufw_firewall
    enable_arch_helpers
    configure_wireless_networking
    configure_time_sync
    apply_basic_os_hardening
    install_status_commands
    install_auto_update_service
    configure_git_defaults
    configure_fish_files
    configure_ssh_client_defaults
    install_fisher_plugins
    set_default_shell
    install_motd
    cleanup_unused_packages_and_cache
    write_install_state "$(selected_profiles_csv)" "$ORIGINAL_SHELL"
    commit_transaction
    trap - ERR

    log "Setup complete. Open a new login session to see the Fish prompt and MOTD."
    if profile_is_selected docker; then
        log "Docker group membership takes effect after $TARGET_USER logs out and back in."
    fi
}

main "$@"
