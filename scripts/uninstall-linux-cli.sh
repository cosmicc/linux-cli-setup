#!/usr/bin/env bash
#
# Remove linux-cli-setup managed configuration. Package removal is intentionally
# opt-in because many recommended CLI packages may have been installed manually.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/linux-cli-common.sh
source "$SCRIPT_DIR/lib/linux-cli-common.sh"
# shellcheck source=scripts/lib/package-install-overrides.sh
source "$SCRIPT_DIR/lib/package-install-overrides.sh"

REMOVE_PACKAGES=0
RESTORE_SHELL=1

show_help() {
    cat <<'HELP'
Usage: sudo ./uninstall.sh [options]

Remove linux-cli-setup managed MOTD and Fish configuration.

Options:
  --remove-packages       Also remove packages for selected or saved profiles.
  --profile NAME[,NAME]   Select package profiles to remove with --remove-packages.
  --profiles NAME[,NAME]  Alias for --profile.
  --all-profiles          Select every supported profile for package removal.
  --keep-shell            Do not restore the user's pre-install default shell.
  --list-profiles         Show available groups.
  --debug                 Show captured installer output and debug details.
  --no-color              Disable colored console output.
  --version               Show version.
  --help                  Show this help.

Default behavior preserves installed packages and restores the saved shell when
state is available. With --remove-packages, saved profiles are removed by
default, including core.
HELP
}

parse_uninstall_args() {
    local remaining=()
    local arg

    while [[ $# -gt 0 ]]; do
        arg="$1"
        case "$arg" in
            --remove-packages)
                REMOVE_PACKAGES=1
                ;;
            --keep-shell)
                RESTORE_SHELL=0
                ;;
            --debug|--no-color|--no-colour)
                remaining+=("$arg")
                ;;
            --help|--version|--profile|--profiles|--profile=*|--profiles=*|--all-profiles|--list-profiles|--)
                remaining+=("$arg")
                if [[ "$arg" == "--profile" || "$arg" == "--profiles" ]]; then
                    shift
                    [[ $# -gt 0 ]] || die "$arg requires a profile name or comma-separated profile list."
                    remaining+=("$1")
                elif [[ "$arg" == "--" ]]; then
                    shift
                    while [[ $# -gt 0 ]]; do
                        remaining+=("$1")
                        shift
                    done
                    break
                fi
                ;;
            *)
                remaining+=("$arg")
                ;;
        esac
        shift
    done

    parse_profile_selection 0 "${remaining[@]}"
}

restore_shell_if_needed() {
    local saved_shell
    local current_shell

    [[ "$RESTORE_SHELL" -eq 1 ]] || return

    saved_shell="$(read_state_value original_shell || true)"
    [[ -n "$saved_shell" && -x "$saved_shell" ]] || return

    current_shell="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
    if [[ "$current_shell" == "$(command -v fish 2>/dev/null || true)" ]]; then
        log "Restoring $TARGET_USER default shell to $saved_shell"
        if command -v chsh >/dev/null 2>&1; then
            run_step_optional "Restoring shell" "$TARGET_USER to $saved_shell" chsh -s "$saved_shell" "$TARGET_USER"
        else
            run_step_optional "Restoring shell" "$TARGET_USER to $saved_shell" usermod --shell "$saved_shell" "$TARGET_USER"
        fi
    fi
}

reenable_motd_snippets() {
    local disabled_file
    local motd_file

    if [[ ! -d /etc/update-motd.d/.linux-cli-setup-disabled ]]; then
        return
    fi

    while IFS= read -r -d '' disabled_file; do
        while IFS= read -r motd_file; do
            [[ -n "$motd_file" && -f "$motd_file" ]] || continue
            log "Re-enabling MOTD snippet $motd_file"
            run_step_optional "Re-enabling MOTD snippet" "$motd_file" chmod a+x "$motd_file"
        done < "$disabled_file"
    done < <(find /etc/update-motd.d/.linux-cli-setup-disabled -type f -name 'disabled-*.txt' -print0)

    run_step_optional "Removing directory" "/etc/update-motd.d/.linux-cli-setup-disabled" rm -rf /etc/update-motd.d/.linux-cli-setup-disabled
}

remove_installed_utility_scripts() {
    local script_file
    local script_name

    [[ -d "$UTILITY_SCRIPT_DIR" ]] || return

    while IFS= read -r -d '' script_file; do
        script_name="$(basename "$script_file")"
        [[ -n "$script_name" ]] || continue
        [[ "${script_name:0:1}" != "." ]] || continue
        remove_file_if_managed_or_backup "/usr/local/bin/$script_name" "$script_file"
    done < <(find "$UTILITY_SCRIPT_DIR" -maxdepth 1 -type f -print0 | sort -z)
}

remove_auto_update_config() {
    local default_config

    if [[ ! -e "$AUTO_UPDATE_CONFIG" && ! -L "$AUTO_UPDATE_CONFIG" ]]; then
        return
    fi

    default_config="$(mktemp)"
    sed \
        -e "s|^AUR_USER=.*|AUR_USER=\"${TARGET_USER}\"|" \
        -e 's|^PUSHOVER_USER_KEY=.*|PUSHOVER_USER_KEY=""|' \
        -e 's|^PUSHOVER_API_TOKEN=.*|PUSHOVER_API_TOKEN=""|' \
        "$AUTO_UPDATE_TEMPLATE_DIR/auto-update.conf" > "$default_config"

    remove_file_if_managed_or_backup "$AUTO_UPDATE_CONFIG" "$default_config"
    rm -f "$default_config"

    if [[ -d "$CONFIG_DIR" ]] && [[ -z "$(find "$CONFIG_DIR" -mindepth 1 -print -quit)" ]]; then
        run_step_optional "Removing directory" "$CONFIG_DIR" rmdir "$CONFIG_DIR"
    fi
}

remove_managed_files() {
    local fish_config_dir="$TARGET_HOME/.config/fish"
    local function_template
    local ssh_dir="$TARGET_HOME/.ssh"
    local ssh_config="$ssh_dir/config"
    local include_line='Include ~/.ssh/conf.d/*.conf'

    remove_file_if_managed_or_backup "$fish_config_dir/config.fish" "$FISH_TEMPLATE_DIR/config.fish"
    remove_file_if_managed_or_backup "$fish_config_dir/fish_plugins" "$FISH_TEMPLATE_DIR/fish_plugins"
    while IFS= read -r -d '' function_template; do
        remove_file_if_managed_or_backup "$fish_config_dir/functions/$(basename "$function_template")" "$function_template"
    done < <(find "$FISH_TEMPLATE_DIR/functions" -maxdepth 1 -type f -name '*.fish' -print0)
    remove_file_if_managed_or_backup /etc/sysctl.d/99-linux-cli-setup-hardening.conf "$SYSCTL_TEMPLATE_DIR/99-linux-cli-setup-hardening.conf"
    run_step_optional "Applying" "remaining sysctl settings" sysctl --system || true
    remove_file_if_managed_or_backup "$ssh_dir/conf.d/00-defaults.conf" "$SSH_TEMPLATE_DIR/00-defaults.conf"
    if [[ -d "$ssh_dir/controlmasters" ]] && [[ -z "$(find "$ssh_dir/controlmasters" -mindepth 1 -print -quit)" ]]; then
        run_step_optional "Removing directory" "$ssh_dir/controlmasters" rmdir "$ssh_dir/controlmasters"
    fi
    if [[ -d "$ssh_dir/conf.d" ]] && [[ -z "$(find "$ssh_dir/conf.d" -mindepth 1 -print -quit)" ]]; then
        run_step_optional "Removing directory" "$ssh_dir/conf.d" rmdir "$ssh_dir/conf.d"
    fi

    if [[ -f "$ssh_config" ]] && [[ "$(tr -d '\n' < "$ssh_config")" == "$include_line" ]]; then
        run_step_optional "Removing file" "$ssh_config" rm -f "$ssh_config"
    fi

    if systemd_available; then
        run_step_optional "Disabling timer" "linux-cli-auto-update.timer" systemctl disable --now linux-cli-auto-update.timer
    fi

    run_step_optional "Removing file" "/usr/local/bin/linux-cli-motd" rm -f /usr/local/bin/linux-cli-motd
    run_step_optional "Removing file" "/usr/local/bin/time-status" rm -f /usr/local/bin/time-status
    run_step_optional "Removing file" "/usr/local/bin/ntp-status" rm -f /usr/local/bin/ntp-status
    remove_installed_utility_scripts
    run_step_optional "Removing file" "/usr/local/sbin/linux-cli-auto-update" rm -f /usr/local/sbin/linux-cli-auto-update
    remove_auto_update_config
    run_step_optional "Removing file" "/etc/update-motd.d/50-linux-cli-setup" rm -f /etc/update-motd.d/50-linux-cli-setup
    run_step_optional "Removing file" "/etc/fish/conf.d/linux-cli-motd.fish" rm -f /etc/fish/conf.d/linux-cli-motd.fish
    run_step_optional "Removing file" "/etc/systemd/system/linux-cli-auto-update.service" rm -f /etc/systemd/system/linux-cli-auto-update.service
    run_step_optional "Removing file" "/etc/systemd/system/linux-cli-auto-update.timer" rm -f /etc/systemd/system/linux-cli-auto-update.timer
    run_step_optional "Removing file" "/etc/cron.d/linux-cli-auto-update" rm -f /etc/cron.d/linux-cli-auto-update
    run_step_optional "Removing file" "/etc/systemd/timesyncd.conf.d/10-linux-cli-setup.conf" rm -f /etc/systemd/timesyncd.conf.d/10-linux-cli-setup.conf

    if systemd_available; then
        run_step_optional "Reloading" "systemd manager configuration" systemctl daemon-reload
    fi

    reenable_motd_snippets
}

select_package_removal_profiles() {
    local profiles

    if [[ "${#SELECTED_PROFILES[@]}" -gt 0 ]]; then
        return
    fi

    if ! install_state_exists; then
        log "No install state found; no saved package profiles selected for removal."
        return
    fi

    profiles="$(state_profiles)"
    SELECTED_PROFILES=()
    add_profile_csv "$profiles"
}

remove_selected_profile_packages() {
    local profile
    local state_profile
    local removal_profiles=()
    local retained_profiles=()
    local saved_profiles=()

    [[ "$REMOVE_PACKAGES" -eq 1 ]] || return
    select_package_removal_profiles

    mapfile -t saved_profiles < <(profiles_csv_to_lines "$(state_profiles)")
    if [[ "$PROFILES_EXPLICIT" -eq 1 ]]; then
        for state_profile in "${saved_profiles[@]}"; do
            if ! profile_is_selected "$state_profile"; then
                retained_profiles+=("$state_profile")
            fi
        done
    fi

    for profile in "${SELECTED_PROFILES[@]}"; do
        removal_profiles+=("$profile")
    done

    if [[ "${#removal_profiles[@]}" -eq 0 ]]; then
        log "No package profiles selected for removal."
        return
    fi

    for profile in "${removal_profiles[@]}"; do
        remove_profile_packages "$profile" "${retained_profiles[@]}"
    done
}

main() {
    parse_uninstall_args "$@"

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
    init_logging uninstall
    init_package_family
    self_update_if_newer "${LINUX_CLI_ENTRYPOINT:-$0}" "$@"
    init_runtime_context
    PACKAGE_STEP_VERB="Uninstalling"
    export PACKAGE_STEP_VERB

    log "Target user: $TARGET_USER"
    remove_managed_files
    restore_static_motd_if_managed
    restore_shell_if_needed
    remove_selected_profile_packages
    run_step_optional "Removing directory" "$STATE_DIR" rm -rf "$STATE_DIR"

    log "Uninstall complete."
}

main "$@"
