#!/usr/bin/env bash
#
# Runtime fixes and availability-aware install overrides.
#
# This file is sourced after linux-cli-common.sh by install/refresh/uninstall
# entrypoints so functions defined here intentionally replace selected
# common-library defaults.

set -Eeuo pipefail

CARGO_FALLBACKS_NOTICE_SHOWN=0
STATIC_MOTD_BACKUP="$CONFIG_DIR/motd.static.original"
UTILITY_SCRIPT_DIR="$PROJECT_ROOT/scripts/utilities"

run_step() {
    local action="$1"
    local item="$2"
    shift 2

    CURRENT_STEP_OUTPUT="$(mktemp)"
    console_line bright_cyan "[linux-cli-setup] ${action}: ${item}"
    debug "Command: $*"

    if "$@" > "$CURRENT_STEP_OUTPUT" 2>&1; then
        debug_step_output
        rm -f "$CURRENT_STEP_OUTPUT"
        CURRENT_STEP_OUTPUT=""
        success "${action} complete: ${item}"
        return 0
    else
        local rc=$?
        error "${action} failed: ${item} (exit $rc)"
        show_step_tail
        rm -f "$CURRENT_STEP_OUTPUT"
        CURRENT_STEP_OUTPUT=""
        return "$rc"
    fi
}

install_debian_package() {
    local package="$1"
    local required="$2"
    local package_label

    package_label="$(package_display_name "$package")"

    if package_is_installed "$package"; then
        debug "apt package $package_label is already installed"
        return 0
    fi

    export DEBIAN_FRONTEND=noninteractive

    if [[ "$required" != "1" ]] && ! package_is_available "$package"; then
        warn "Skipping unavailable optional apt package '$package_label'."
        return 0
    fi

    if run_step "${PACKAGE_STEP_VERB:-Installing}" "apt package $package_label" apt-get install -y --no-install-recommends "$package"; then
        record_package_install_rollback "$package"
        return 0
    fi

    [[ "$required" == "1" ]] && return 1
    warn "Could not install optional apt package '$package_label'. It may not be available for this release."
    return 0
}

arch_package_available_in_pacman() {
    local package="$1"
    pacman -Si "$package" >/dev/null 2>&1
}

arch_package_available_in_yay() {
    local package="$1"

    command -v yay >/dev/null 2>&1 || return 1
    run_as_target yay -Si "$package" >/dev/null 2>&1
}

install_arch_package() {
    local package="$1"
    local required="$2"
    local package_label

    package_label="$(package_display_name "$package")"

    if package_is_installed "$package"; then
        debug "pacman package $package_label is already installed"
        return 0
    fi

    if [[ "$required" != "1" ]]; then
        if arch_package_available_in_pacman "$package"; then
            if run_step "${PACKAGE_STEP_VERB:-Installing}" "pacman package $package_label" pacman -S --needed --noconfirm "$package"; then
                record_package_install_rollback "$package"
                return 0
            fi
            warn "Could not install optional Arch package '$package_label' from pacman."
            return 0
        fi

        if arch_package_available_in_yay "$package"; then
            if run_step_optional "${PACKAGE_STEP_VERB:-Installing}" "AUR package $package_label" run_as_target yay -S --needed --noconfirm "$package"; then
                record_package_install_rollback "$package"
            fi
            return 0
        fi

        warn "Skipping unavailable optional Arch package '$package_label'."
        return 0
    fi

    if run_step "${PACKAGE_STEP_VERB:-Installing}" "pacman package $package_label" pacman -S --needed --noconfirm "$package"; then
        record_package_install_rollback "$package"
        return 0
    fi

    return 1
}

install_cargo_tool_if_missing() {
    local command_name="$1"
    local crate_name="$2"
    local current_minimum_rust="${3:-}"
    local compatible_crate_version="${4:-}"
    local package_label
    local rustc_version=""
    local crate_version=""

    package_label="$(package_display_name "$crate_name")"
    if target_command_exists "$command_name"; then
        debug "Comfort tool $package_label is already available"
        return 0
    fi

    if [[ "${LINUX_CLI_ENABLE_CARGO_FALLBACKS:-1}" == "0" ]]; then
        if [[ "$CARGO_FALLBACKS_NOTICE_SHOWN" -eq 0 ]]; then
            warn "Skipping cargo source-build fallbacks for missing comfort tools because LINUX_CLI_ENABLE_CARGO_FALLBACKS=0."
            CARGO_FALLBACKS_NOTICE_SHOWN=1
        fi
        debug "Skipping cargo fallback for $package_label."
        return 0
    fi

    if ! target_has_cargo; then
        warn "cargo is unavailable; skipping fallback install for $package_label"
        return 0
    fi

    if [[ -n "$current_minimum_rust" && -n "$compatible_crate_version" ]]; then
        rustc_version="$(target_rustc_version)"
        if [[ -z "$rustc_version" ]] || ! version_number_at_least "$rustc_version" "$current_minimum_rust"; then
            crate_version="$compatible_crate_version"
            package_label="${package_label}@${crate_version}"
            if [[ -n "$rustc_version" ]]; then
                log "Using cargo fallback $package_label because rustc $rustc_version is below $current_minimum_rust for newer $crate_name releases."
            else
                warn "Could not detect rustc version; using compatible cargo fallback $package_label."
            fi
        fi
    fi

    # shellcheck disable=SC2016
    if [[ -n "$crate_version" ]]; then
        if run_step_optional "${PACKAGE_STEP_VERB:-Installing}" "cargo tool $package_label" \
            run_as_target bash -lc 'PATH="$HOME/.cargo/bin:$PATH"; cargo install --locked --version "$2" "$1"' bash "$crate_name" "$crate_version"; then
            record_rollback_cmd "runuser -u $(shell_quote "$TARGET_USER") -- env HOME=$(shell_quote "$TARGET_HOME") PATH=$(shell_quote "$TARGET_HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin") cargo uninstall $(shell_quote "$crate_name")"
        fi
    else
        if run_step_optional "${PACKAGE_STEP_VERB:-Installing}" "cargo tool $package_label" \
            run_as_target bash -lc 'PATH="$HOME/.cargo/bin:$PATH"; cargo install --locked "$1"' bash "$crate_name"; then
            record_rollback_cmd "runuser -u $(shell_quote "$TARGET_USER") -- env HOME=$(shell_quote "$TARGET_HOME") PATH=$(shell_quote "$TARGET_HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin") cargo uninstall $(shell_quote "$crate_name")"
        fi
    fi
}

install_utility_scripts() {
    local script_file
    local script_name

    if [[ ! -d "$UTILITY_SCRIPT_DIR" ]]; then
        debug "Utility script directory not found: $UTILITY_SCRIPT_DIR"
        return 0
    fi

    log "Installing utility scripts from $UTILITY_SCRIPT_DIR"
    while IFS= read -r -d '' script_file; do
        script_name="$(basename "$script_file")"
        [[ -n "$script_name" ]] || continue
        [[ "${script_name:0:1}" != "." ]] || continue
        install_owned_file "$script_file" "/usr/local/bin/$script_name" 0755 root root
    done < <(find "$UTILITY_SCRIPT_DIR" -maxdepth 1 -type f -print0 | sort -z)

    if [[ -f "$UTILITY_SCRIPT_DIR/timecheck" ]]; then
        install_owned_symlink timecheck /usr/local/bin/ntpcheck root root
    fi

    if [[ -f "$UTILITY_SCRIPT_DIR/dockercheck" ]]; then
        remove_file_if_managed_or_backup /usr/local/bin/docker-status "$UTILITY_SCRIPT_DIR/dockercheck"
    fi
}

install_status_commands() {
    install_owned_file "$BIN_TEMPLATE_DIR/time-status" /usr/local/bin/time-status 0755 root root
    install_owned_file "$BIN_TEMPLATE_DIR/ntp-status" /usr/local/bin/ntp-status 0755 root root
    install_utility_scripts
}

install_custom_fish_prompt() {
    local fish_config_dir="$TARGET_HOME/.config/fish"
    local prompt_template="$FISH_TEMPLATE_DIR/functions/fish_prompt.fish"

    if [[ ! -f "$prompt_template" ]]; then
        warn "Fish prompt template not found: $prompt_template"
        return 0
    fi

    install_owned_file "$prompt_template" "$fish_config_dir/functions/fish_prompt.fish" 0644 "$TARGET_USER" "$TARGET_GROUP"
}

fish_plugin_is_registered() {
    local plugin_name="$1"

    run_as_target fish -lc "functions -q fisher; and fisher list | string match -q -- '$plugin_name'" >/dev/null 2>&1
}

prepare_fisher_conflict_file() {
    local conflict_path="$1"
    local description="$2"
    local managed_template="${3:-}"

    [[ -e "$conflict_path" || -L "$conflict_path" ]] || return 0

    if [[ -n "$managed_template" && -f "$managed_template" ]] && cmp -s "$managed_template" "$conflict_path"; then
        log "Removing managed $description before Fisher plugin installation."
        record_rollback_cmd "install -o $(shell_quote "$TARGET_USER") -g $(shell_quote "$TARGET_GROUP") -m 0644 $(shell_quote "$managed_template") $(shell_quote "$conflict_path")"
        run_step "Removing managed conflict" "$conflict_path" rm -f "$conflict_path"
        return 0
    fi

    warn "$conflict_path conflicts with managed Fisher plugin installation; backing it up before continuing."
    backup_existing_path "$conflict_path"
}

prepare_fisher_plugin_conflicts() {
    local fish_config_dir="$TARGET_HOME/.config/fish"
    local prompt_template="$FISH_TEMPLATE_DIR/functions/fish_prompt.fish"

    if ! fish_plugin_is_registered "IlanCosman/tide@v6" && ! fish_plugin_is_registered "ilancosman/tide@v6"; then
        prepare_fisher_conflict_file "$fish_config_dir/functions/fish_prompt.fish" "Tide prompt file" "$prompt_template"
    fi

    if ! fish_plugin_is_registered "franciscolourenco/done"; then
        prepare_fisher_conflict_file "$fish_config_dir/conf.d/done.fish" "done plugin hook"
    fi
}

verify_tide_helpers_installed() {
    # shellcheck disable=SC2016
    run_step "Verifying" "Tide Fish helpers" run_as_target fish -lc '
set -l required_tide_helpers \
    _tide_remove_unusable_items \
    _tide_cache_variables \
    _tide_parent_dirs \
    _tide_pwd \
    _tide_1_line_prompt \
    _tide_2_line_prompt

for helper in $required_tide_helpers
    if not functions -q $helper
        echo "Missing Tide helper function: $helper" >&2
        exit 1
    end
end
'
}

configure_fish_files() {
    local config_root="$TARGET_HOME/.config"
    local fish_config_dir="$config_root/fish"

    log "Installing Fish configuration for $TARGET_USER"
    run_step "Creating directory" "$config_root" install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0755 -d \
        "$config_root" \
        "$fish_config_dir" \
        "$fish_config_dir/conf.d" \
        "$fish_config_dir/functions"

    run_step_optional "Creating directory" "$config_root/atuin" install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0700 -d "$config_root/atuin" || true
    run_step_optional "Setting ownership" "$config_root/atuin" chown -R "$TARGET_USER:$TARGET_GROUP" "$config_root/atuin" || true

    install_owned_file "$FISH_TEMPLATE_DIR/config.fish" "$fish_config_dir/config.fish" 0644 "$TARGET_USER" "$TARGET_GROUP"
    install_owned_file "$FISH_TEMPLATE_DIR/fish_plugins" "$fish_config_dir/fish_plugins" 0644 "$TARGET_USER" "$TARGET_GROUP"

    if profile_is_selected comfort; then
        install_fish_function_templates "${COMFORT_FISH_FUNCTIONS[@]}"
    fi

    if profile_is_selected wireless; then
        install_fish_function_templates "${WIRELESS_FISH_FUNCTIONS[@]}"
    fi
}

install_fisher_plugins() {
    local plugin_list
    plugin_list="$(grep -Ev '^[[:space:]]*(#|$)' "$FISH_TEMPLATE_DIR/fish_plugins" | tr '\n' ' ')"

    log "Installing or updating Fisher and Fish plugins for $TARGET_USER"
    prepare_fisher_plugin_conflicts
    run_step "Installing" "Fisher and Fish plugins" run_as_target fish -lc "curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; and fisher install $plugin_list"
    verify_tide_helpers_installed

    log "Applying Tide prompt settings"
    run_step "Configuring" "Tide prompt" run_as_target fish "$FISH_TEMPLATE_DIR/configure_tide.fish"
    install_custom_fish_prompt
}

update_fisher_plugins() {
    local plugin_list

    if ! command -v fish >/dev/null 2>&1; then
        warn "Fish is not installed; skipping Fisher plugin update"
        return
    fi

    log "Updating Fisher plugins for $TARGET_USER"
    plugin_list="$(grep -Ev '^[[:space:]]*(#|$)' "$FISH_TEMPLATE_DIR/fish_plugins" | tr '\n' ' ')"
    prepare_fisher_plugin_conflicts
    run_step "Updating" "Fisher plugins" run_as_target fish -lc "if functions -q fisher; fisher install $plugin_list; and fisher update; else curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; and fisher install $plugin_list; end"
    verify_tide_helpers_installed
    run_step "Configuring" "Tide prompt" run_as_target fish "$FISH_TEMPLATE_DIR/configure_tide.fish"
    install_custom_fish_prompt
}

suppress_static_motd() {
    local motd_path="/etc/motd"
    local tmp_file
    local backup

    [[ "${MOTD_MODE:-replace}" == "replace" ]] || return 0
    [[ -e "$motd_path" ]] || return 0

    if [[ -L "$motd_path" ]]; then
        warn "Skipping static MOTD suppression because $motd_path is a symlink."
        return 0
    fi

    [[ -f "$motd_path" ]] || return 0
    if ! grep -Fq 'The programs included with the Debian GNU/Linux system are free software;' "$motd_path" && \
        ! grep -Fq 'Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY' "$motd_path"; then
        return 0
    fi

    run_step "Creating directory" "$CONFIG_DIR" install -m 0700 -d "$CONFIG_DIR"
    if [[ ! -f "$STATIC_MOTD_BACKUP" ]]; then
        run_step "Backing up" "$motd_path to $STATIC_MOTD_BACKUP" cp -p "$motd_path" "$STATIC_MOTD_BACKUP"
        chmod 0600 "$STATIC_MOTD_BACKUP"
    fi

    tmp_file="$(mktemp)"
    awk '
        /^The programs included with the Debian GNU\/Linux system are free software;/ {
            skip = 1
            next
        }
        skip && /^permitted by applicable law\.$/ {
            skip = 0
            next
        }
        skip {
            next
        }
        {
            print
        }
    ' "$motd_path" > "$tmp_file"

    if cmp -s "$motd_path" "$tmp_file"; then
        rm -f "$tmp_file"
        return 0
    fi

    backup="${motd_path}.linux-cli-setup.${TIMESTAMP}.bak"
    run_step "Backing up" "$motd_path" cp -p "$motd_path" "$backup"
    record_rollback_cmd "mv -f $(shell_quote "$backup") $(shell_quote "$motd_path")"
    run_step "Updating" "$motd_path" install -m 0644 "$tmp_file" "$motd_path"
    rm -f "$tmp_file"
}

restore_static_motd_if_managed() {
    [[ -f "$STATIC_MOTD_BACKUP" ]] || return 0

    log "Restoring static MOTD from $STATIC_MOTD_BACKUP"
    run_step_optional "Restoring file" "/etc/motd" install -m 0644 "$STATIC_MOTD_BACKUP" /etc/motd || true
    run_step_optional "Removing file" "$STATIC_MOTD_BACKUP" rm -f "$STATIC_MOTD_BACKUP" || true
}

remove_linux_cli_motd_hooks() {
    remove_file_if_managed_or_backup "$MOTD_UPDATE_SNIPPET" "$MOTD_TEMPLATE"
    remove_file_if_managed_or_backup "$LEGACY_MOTD_UPDATE_SNIPPET" "$MOTD_TEMPLATE"
    remove_file_if_managed_or_backup /etc/fish/conf.d/linux-cli-motd.fish "$FISH_TEMPLATE_DIR/conf.d/linux-cli-motd.fish"
}

install_motd() {
    case "${MOTD_MODE:-replace}" in
        keep)
            log "Keeping existing MOTD and removing linux-cli-setup login MOTD hooks."
            reenable_motd_snippets
            restore_static_motd_if_managed
            remove_linux_cli_motd_hooks
            remove_file_if_managed_or_backup /usr/local/bin/linux-cli-motd "$MOTD_TEMPLATE"
            remove_unifetch_motd_config
            return
            ;;
        combine)
            log "Combining existing MOTD with linux-cli-setup dynamic status."
            reenable_motd_snippets
            restore_static_motd_if_managed
            ;;
        replace)
            log "Replacing existing MOTD entries with linux-cli-setup dynamic status."
            ;;
        *)
            die "Unknown MOTD mode '${MOTD_MODE:-}'. Use keep, replace, or combine."
            ;;
    esac

    log "Installing dynamic MOTD script"
    install_unifetch_motd_config
    install_owned_file "$MOTD_TEMPLATE" /usr/local/bin/linux-cli-motd 0755 root root

    if [[ -d /etc/update-motd.d ]]; then
        local state_dir="/etc/update-motd.d/.linux-cli-setup-disabled"
        run_step "Creating directory" "$state_dir" mkdir -p "$state_dir"

        log "Installing $MOTD_UPDATE_SNIPPET"
        install_owned_file "$MOTD_TEMPLATE" "$MOTD_UPDATE_SNIPPET" 0755 root root
        remove_file_if_managed_or_backup "$LEGACY_MOTD_UPDATE_SNIPPET" "$MOTD_TEMPLATE"

        if [[ "${MOTD_MODE:-replace}" == "replace" ]]; then
            log "Disabling other executable update-motd snippets; use --motd combine to keep them enabled"
            while IFS= read -r -d '' motd_file; do
                [[ "$motd_file" == "$MOTD_UPDATE_SNIPPET" ]] && continue
                run_step "Disabling MOTD snippet" "$motd_file" chmod a-x "$motd_file"
                record_rollback_cmd "chmod a+x $(shell_quote "$motd_file")"
                printf '%s\n' "$motd_file" >> "$state_dir/disabled-${TIMESTAMP}.txt"
            done < <(find /etc/update-motd.d -maxdepth 1 -type f -perm /111 -print0)
        fi

        suppress_static_motd
        return
    fi

    log "No /etc/update-motd.d directory found; installing Fish login MOTD hook"
    run_step "Creating directory" "/etc/fish/conf.d" install -m 0755 -d /etc/fish/conf.d
    install_owned_file "$FISH_TEMPLATE_DIR/conf.d/linux-cli-motd.fish" /etc/fish/conf.d/linux-cli-motd.fish 0644 root root
    suppress_static_motd
}
