#!/usr/bin/env bash
#
# Refresh system packages, selected profile packages, Fish plugins, prompt
# settings, and the MOTD template for an existing linux-cli-setup installation.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/linux-cli-common.sh
source "$SCRIPT_DIR/lib/linux-cli-common.sh"
# shellcheck source=scripts/lib/package-install-overrides.sh
source "$SCRIPT_DIR/lib/package-install-overrides.sh"

show_help() {
    cat <<'HELP'
Usage: sudo ./update.sh [options]

Update system packages and refresh linux-cli-setup managed configuration.

Options:
  --profile NAME[,NAME]   Update one or more groups in addition to core.
  --profiles NAME[,NAME]  Alias for --profile.
  --all-profiles          Update every supported group.
  --list-profiles         Show available groups.
  --debug                 Show captured installer output and debug details.
  --no-color              Disable colored console output.
  --version               Show version.
  --help                  Show this help.

If no group is given, the script uses the groups saved by the last install.
HELP
}

select_state_profiles_if_needed() {
    local profiles

    if [[ "$PROFILES_EXPLICIT" -eq 1 ]]; then
        return
    fi

    profiles="$(state_profiles)"
    SELECTED_PROFILES=()
    add_profile_csv "$profiles"
    ensure_core_profile_first
}

update_selected_profiles() {
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
            update_dev_tools
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
    init_logging update
    self_update_if_newer "${LINUX_CLI_ENTRYPOINT:-$0}" "$@"
    start_transaction
    trap transaction_error_trap ERR
    init_runtime_context
    PACKAGE_STEP_VERB="Updating"
    export PACKAGE_STEP_VERB
    select_state_profiles_if_needed

    log "Detected package family: $PACKAGE_FAMILY"
    log "Target user: $TARGET_USER"
    log "Selected profiles: $(selected_profiles_csv)"

    update_package_database_and_system
    ensure_yay_on_arch
    update_selected_profiles
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
    update_fisher_plugins
    install_motd
    cleanup_unused_packages_and_cache
    write_install_state "$(selected_profiles_csv)" "$ORIGINAL_SHELL"
    commit_transaction
    trap - ERR

    log "Update complete."
}

main "$@"
