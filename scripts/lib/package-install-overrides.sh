#!/usr/bin/env bash
#
# Runtime fixes and availability-aware install overrides.
#
# This file is sourced after linux-cli-common.sh by install/update entrypoints so
# functions defined here intentionally replace selected common-library defaults.

set -Eeuo pipefail

CARGO_FALLBACKS_NOTICE_SHOWN=0

run_step() {
    local action="$1"
    local item="$2"
    shift 2

    CURRENT_STEP_OUTPUT="$(mktemp)"
    console_line blue "[linux-cli-setup] ${action}: ${item}"
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

    if package_is_installed "$package"; then
        debug "apt package $package is already installed"
        return 0
    fi

    export DEBIAN_FRONTEND=noninteractive

    if [[ "$required" != "1" ]] && ! package_is_available "$package"; then
        warn "Skipping unavailable optional apt package '$package'."
        return 0
    fi

    if run_step "${PACKAGE_STEP_VERB:-Installing}" "apt package $package" apt-get install -y --no-install-recommends "$package"; then
        record_package_install_rollback "$package"
        return 0
    fi

    [[ "$required" == "1" ]] && return 1
    warn "Could not install optional apt package '$package'. It may not be available for this release."
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

    if package_is_installed "$package"; then
        debug "pacman package $package is already installed"
        return 0
    fi

    if [[ "$required" != "1" ]]; then
        if arch_package_available_in_pacman "$package"; then
            if run_step "${PACKAGE_STEP_VERB:-Installing}" "pacman package $package" pacman -S --needed --noconfirm "$package"; then
                record_package_install_rollback "$package"
                return 0
            fi
            warn "Could not install optional Arch package '$package' from pacman."
            return 0
        fi

        if arch_package_available_in_yay "$package"; then
            if run_step_optional "${PACKAGE_STEP_VERB:-Installing}" "AUR package $package" run_as_target yay -S --needed --noconfirm "$package"; then
                record_package_install_rollback "$package"
            fi
            return 0
        fi

        warn "Skipping unavailable optional Arch package '$package'."
        return 0
    fi

    if run_step "${PACKAGE_STEP_VERB:-Installing}" "pacman package $package" pacman -S --needed --noconfirm "$package"; then
        record_package_install_rollback "$package"
        return 0
    fi

    return 1
}

install_cargo_tool_if_missing() {
    local command_name="$1"
    local crate_name="$2"

    if target_command_exists "$command_name"; then
        debug "Comfort tool $command_name is already available"
        return 0
    fi

    if [[ "${LINUX_CLI_ENABLE_CARGO_FALLBACKS:-0}" != "1" ]]; then
        if [[ "$CARGO_FALLBACKS_NOTICE_SHOWN" -eq 0 ]]; then
            warn "Skipping cargo source-build fallbacks for missing comfort tools. Set LINUX_CLI_ENABLE_CARGO_FALLBACKS=1 to enable them."
            CARGO_FALLBACKS_NOTICE_SHOWN=1
        fi
        debug "Skipping cargo fallback for $command_name ($crate_name)."
        return 0
    fi

    if ! target_has_cargo; then
        warn "cargo is unavailable; skipping fallback install for $command_name"
        return 0
    fi

    # shellcheck disable=SC2016
    if run_step_optional "${PACKAGE_STEP_VERB:-Installing}" "cargo tool $crate_name" \
        run_as_target bash -lc 'PATH="$HOME/.cargo/bin:$PATH"; cargo install --locked "$1"' bash "$crate_name"; then
        record_rollback_cmd "runuser -u $(shell_quote "$TARGET_USER") -- env HOME=$(shell_quote "$TARGET_HOME") PATH=$(shell_quote "$TARGET_HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin") cargo uninstall $(shell_quote "$crate_name")"
    fi
}
