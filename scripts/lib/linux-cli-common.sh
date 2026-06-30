#!/usr/bin/env bash
#
# Shared helpers for linux-cli-setup install, update, and uninstall scripts.

set -Eeuo pipefail

COMMON_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$COMMON_SCRIPT_DIR/../.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"
FISH_TEMPLATE_DIR="$PROJECT_ROOT/templates/fish"
MOTD_TEMPLATE="$PROJECT_ROOT/templates/motd/linux-cli-motd"
AUTO_UPDATE_TEMPLATE_DIR="$PROJECT_ROOT/templates/auto-update"
BIN_TEMPLATE_DIR="$PROJECT_ROOT/templates/bin"
SYSTEMD_TEMPLATE_DIR="$PROJECT_ROOT/templates/systemd"
CRON_TEMPLATE_DIR="$PROJECT_ROOT/templates/cron"
STATE_DIR="/var/lib/linux-cli-setup"
STATE_FILE="$STATE_DIR/install.env"
CONFIG_DIR="/etc/linux-cli-setup"
AUTO_UPDATE_CONFIG="/etc/linux-cli-setup/auto-update.conf"
LOG_DIR="/var/log/linux-cli-setup"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"

SUPPORTED_PROFILES=(core dev netops diagnostics docker desktop)
SELECTED_PROFILES=()
PROFILES_EXPLICIT=0
PROFILE_POSITIONAL_ARGS=()
DEBUG=0
USE_COLOR=1
LOG_FILE=""
CURRENT_STEP_OUTPUT=""
ROLLBACK_FILE=""
ROLLBACK_ENABLED=0
ROLLBACK_RUNNING=0

if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
    USE_COLOR=0
fi

color_code() {
    case "$1" in
        blue) printf '\033[34m' ;;
        green) printf '\033[32m' ;;
        yellow) printf '\033[33m' ;;
        red) printf '\033[31m' ;;
        cyan) printf '\033[36m' ;;
        dim) printf '\033[2m' ;;
        reset) printf '\033[0m' ;;
        *) printf '' ;;
    esac
}

console_line() {
    local color="$1"
    local message="$2"
    local colored_message

    if [[ "$USE_COLOR" -eq 1 ]]; then
        colored_message="$(color_code "$color")${message}$(color_code reset)"
        printf '%b\n' "$colored_message"
    else
        printf '%s\n' "$message"
    fi

    if [[ -n "$LOG_FILE" ]]; then
        printf '%s\n' "$message" >> "$LOG_FILE"
    fi
}

log() {
    console_line cyan "[linux-cli-setup] $*"
}

warn() {
    console_line yellow "[linux-cli-setup] WARNING: $*"
}

debug() {
    [[ "$DEBUG" -eq 1 ]] || return 0
    console_line dim "[linux-cli-setup] DEBUG: $*"
}

success() {
    console_line green "[linux-cli-setup] OK: $*"
}

error() {
    console_line red "[linux-cli-setup] ERROR: $*"
}

die() {
    error "$*"
    show_step_tail
    rollback_changes
    exit 1
}

init_logging() {
    local action="$1"

    install -m 0755 -d "$LOG_DIR"
    LOG_FILE="$LOG_DIR/${action}-${TIMESTAMP}.log"
    touch "$LOG_FILE"
    chmod 0644 "$LOG_FILE"
    log "Logging to $LOG_FILE"
}

show_step_tail() {
    local lines="${1:-25}"

    [[ -n "${CURRENT_STEP_OUTPUT:-}" && -f "$CURRENT_STEP_OUTPUT" ]] || return 0
    warn "Last output from failed step:"
    tail -n "$lines" "$CURRENT_STEP_OUTPUT" | while IFS= read -r line; do
        console_line red "  $line"
    done
}

debug_step_output() {
    [[ "$DEBUG" -eq 1 ]] || return 0
    [[ -n "${CURRENT_STEP_OUTPUT:-}" && -s "$CURRENT_STEP_OUTPUT" ]] || return 0

    debug "Captured command output follows:"
    while IFS= read -r line; do
        console_line dim "  $line"
    done < "$CURRENT_STEP_OUTPUT"
}

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
    fi

    local rc=$?
    error "${action} failed: ${item} (exit $rc)"
    show_step_tail
    rm -f "$CURRENT_STEP_OUTPUT"
    CURRENT_STEP_OUTPUT=""
    return "$rc"
}

run_step_optional() {
    local action="$1"
    local item="$2"
    shift 2

    if ! run_step "$action" "$item" "$@"; then
        warn "Continuing after optional failure: $item"
        return 1
    fi

    return 0
}

shell_quote() {
    printf '%q' "$1"
}

start_transaction() {
    ROLLBACK_FILE="$(mktemp)"
    ROLLBACK_ENABLED=1
    debug "Rollback transaction started at $ROLLBACK_FILE"
}

commit_transaction() {
    ROLLBACK_ENABLED=0
    [[ -n "$ROLLBACK_FILE" ]] && rm -f "$ROLLBACK_FILE"
    ROLLBACK_FILE=""
    debug "Rollback transaction committed"
}

record_rollback_cmd() {
    [[ "$ROLLBACK_ENABLED" -eq 1 && -n "$ROLLBACK_FILE" ]] || return 0
    printf '%s\n' "$*" >> "$ROLLBACK_FILE"
}

rollback_changes() {
    local rollback_command

    [[ "$ROLLBACK_ENABLED" -eq 1 ]] || return 0
    [[ "$ROLLBACK_RUNNING" -eq 0 ]] || return 0
    [[ -n "$ROLLBACK_FILE" && -f "$ROLLBACK_FILE" ]] || return 0

    ROLLBACK_RUNNING=1
    warn "Rolling back changes from this run."

    while IFS= read -r rollback_command; do
        [[ -n "$rollback_command" ]] || continue
        debug "Rollback command: $rollback_command"
        if ! bash -c "$rollback_command" >> "$LOG_FILE" 2>&1; then
            warn "Rollback command failed: $rollback_command"
        fi
    done < <(tac "$ROLLBACK_FILE")

    ROLLBACK_ENABLED=0
    ROLLBACK_RUNNING=0
}

transaction_error_trap() {
    local rc=$?

    [[ "$rc" -eq 0 ]] && return 0
    error "Script failed with exit code $rc."
    show_step_tail
    rollback_changes
    exit "$rc"
}

project_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        tr -d '[:space:]' < "$VERSION_FILE"
        return
    fi

    printf '0.1a'
}

print_version() {
    printf 'linux-cli-setup %s\n' "$(project_version)"
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        die "Run this command with sudo or as root."
    fi
}

read_state_value() {
    local key="$1"

    [[ -f "$STATE_FILE" ]] || return 1
    awk -F= -v key="$key" '$1 == key { value = substr($0, index($0, "=") + 1) } END { if (value != "") print value }' "$STATE_FILE"
}

detect_target_user() {
    local state_user

    if [[ -n "${TARGET_USER:-}" ]]; then
        printf '%s\n' "$TARGET_USER"
        return
    fi

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
        printf '%s\n' "$SUDO_USER"
        return
    fi

    state_user="$(read_state_value target_user || true)"
    if [[ -n "$state_user" ]]; then
        printf '%s\n' "$state_user"
        return
    fi

    die "Could not determine the target user. Run with sudo or set TARGET_USER=username."
}

detect_package_family() {
    if command -v pacman >/dev/null 2>&1; then
        printf 'arch\n'
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        printf 'debian\n'
        return
    fi

    die "Unsupported distribution. This project supports Arch/pacman and Debian/Ubuntu/apt systems."
}

init_runtime_context() {
    TARGET_USER="$(detect_target_user)"
    id "$TARGET_USER" >/dev/null 2>&1 || die "Target user $TARGET_USER does not exist."

    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    TARGET_GROUP="$(id -gn "$TARGET_USER")"
    ORIGINAL_SHELL="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
    PACKAGE_FAMILY="$(detect_package_family)"

    [[ -d "$TARGET_HOME" ]] || die "Target home directory $TARGET_HOME does not exist."

    export TARGET_USER TARGET_HOME TARGET_GROUP ORIGINAL_SHELL PACKAGE_FAMILY
}

run_as_target() {
    runuser -u "$TARGET_USER" -- env \
        HOME="$TARGET_HOME" \
        USER="$TARGET_USER" \
        LOGNAME="$TARGET_USER" \
        XDG_CONFIG_HOME="$TARGET_HOME/.config" \
        "$@"
}

systemd_available() {
    command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]
}

profile_description() {
    case "$1" in
        core)
            printf 'always installed CLI baseline, Fish prompt, Git defaults, MOTD, and distro helpers'
            ;;
        dev)
            printf 'Python, C/C++ build tools, Neovim, uv, pipx tools, and developer Git helpers'
            ;;
        netops)
            printf 'DNS, packet capture, port scanning, VPN, SSH, transfer, and MSP troubleshooting tools'
            ;;
        diagnostics)
            printf 'hardware, disk, sensor, I/O, network usage, tracing, and process diagnostics'
            ;;
        docker)
            printf 'Docker host packages, Compose plugin, Docker CLI helpers, and Fish Docker aliases'
            ;;
        desktop)
            printf 'GUI workstation clipboard, desktop integration, and notification helpers'
            ;;
        *)
            return 1
            ;;
    esac
}

print_profiles() {
    local profile

    for profile in "${SUPPORTED_PROFILES[@]}"; do
        printf '%-12s %s\n' "$profile" "$(profile_description "$profile")"
    done
}

is_supported_profile() {
    local profile="$1"
    local supported

    for supported in "${SUPPORTED_PROFILES[@]}"; do
        [[ "$profile" == "$supported" ]] && return 0
    done

    return 1
}

add_profile() {
    local profile="$1"
    local existing

    [[ -n "$profile" ]] || return 0
    is_supported_profile "$profile" || die "Unknown profile '$profile'. Run with --list-profiles to see valid profiles."

    for existing in "${SELECTED_PROFILES[@]}"; do
        [[ "$existing" == "$profile" ]] && return 0
    done

    SELECTED_PROFILES+=("$profile")
}

add_profile_csv() {
    local raw="$1"
    local profile
    local -a parsed_profiles

    IFS=',' read -r -a parsed_profiles <<< "$raw"
    for profile in "${parsed_profiles[@]}"; do
        profile="${profile//[[:space:]]/}"
        add_profile "$profile"
    done
}

parse_profile_selection() {
    local include_core="$1"
    shift

    local select_all=0
    SELECTED_PROFILES=()
    PROFILE_POSITIONAL_ARGS=()
    PROFILES_EXPLICIT=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile=*)
                PROFILES_EXPLICIT=1
                add_profile_csv "${1#*=}"
                ;;
            --profiles=*)
                PROFILES_EXPLICIT=1
                add_profile_csv "${1#*=}"
                ;;
            --profile|--profiles)
                local option="$1"
                shift
                [[ $# -gt 0 ]] || die "$option requires a profile name or comma-separated profile list."
                PROFILES_EXPLICIT=1
                add_profile_csv "$1"
                ;;
            --all-profiles)
                PROFILES_EXPLICIT=1
                select_all=1
                ;;
            --list-profiles)
                print_profiles
                exit 0
                ;;
            --debug)
                DEBUG=1
                ;;
            --no-color|--no-colour)
                USE_COLOR=0
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    PROFILE_POSITIONAL_ARGS+=("$1")
                    shift
                done
                break
                ;;
            *)
                PROFILE_POSITIONAL_ARGS+=("$1")
                ;;
        esac
        shift
    done

    if [[ "$select_all" -eq 1 ]]; then
        SELECTED_PROFILES=("${SUPPORTED_PROFILES[@]}")
    fi

    if [[ "$include_core" == "1" ]]; then
        if [[ "${#SELECTED_PROFILES[@]}" -eq 0 ]]; then
            SELECTED_PROFILES=(core)
        else
            add_profile core
        fi
    fi

    export PROFILES_EXPLICIT
}

selected_profiles_csv() {
    local IFS=,
    printf '%s' "${SELECTED_PROFILES[*]}"
}

state_profiles() {
    local profiles

    profiles="$(read_state_value profiles || true)"
    if [[ -n "$profiles" ]]; then
        printf '%s\n' "$profiles"
        return
    fi

    printf 'core\n'
}

write_install_state() {
    local profiles_csv="$1"
    local original_shell="$2"
    local stored_original_shell
    local state_backup=""

    stored_original_shell="$(read_state_value original_shell || true)"
    if [[ -n "$stored_original_shell" ]]; then
        original_shell="$stored_original_shell"
    fi

    run_step "Creating directory" "$STATE_DIR" install -m 0755 -d "$STATE_DIR"
    if [[ -f "$STATE_FILE" ]]; then
        state_backup="${STATE_FILE}.linux-cli-setup.${TIMESTAMP}.bak"
        run_step "Backing up" "$STATE_FILE" cp -p "$STATE_FILE" "$state_backup"
        record_rollback_cmd "mv -f $(shell_quote "$state_backup") $(shell_quote "$STATE_FILE")"
    else
        record_rollback_cmd "rm -f $(shell_quote "$STATE_FILE")"
    fi

    {
        printf 'target_user=%s\n' "$TARGET_USER"
        printf 'target_home=%s\n' "$TARGET_HOME"
        printf 'package_family=%s\n' "$PACKAGE_FAMILY"
        printf 'profiles=%s\n' "$profiles_csv"
        printf 'original_shell=%s\n' "$original_shell"
        printf 'updated_at=%s\n' "$(date -Iseconds)"
    } > "$STATE_FILE"
    chmod 0644 "$STATE_FILE"
}

backup_existing_path() {
    local path="$1"

    if [[ -e "$path" || -L "$path" ]]; then
        local backup="${path}.linux-cli-setup.${TIMESTAMP}.bak"
        log "Backing up $path to $backup"
        run_step "Backing up" "$path" mv "$path" "$backup"
        record_rollback_cmd "rm -rf $(shell_quote "$path"); mv -f $(shell_quote "$backup") $(shell_quote "$path")"
    fi
}

install_owned_file() {
    local source="$1"
    local destination="$2"
    local mode="$3"
    local owner="$4"
    local group="$5"

    run_step "Creating directory" "$(dirname "$destination")" mkdir -p "$(dirname "$destination")"

    if [[ -e "$destination" || -L "$destination" ]]; then
        if cmp -s "$source" "$destination"; then
            run_step "Refreshing file" "$destination" install -o "$owner" -g "$group" -m "$mode" "$source" "$destination"
            return
        fi
        backup_existing_path "$destination"
    else
        record_rollback_cmd "rm -f $(shell_quote "$destination")"
    fi

    run_step "Installing file" "$destination" install -o "$owner" -g "$group" -m "$mode" "$source" "$destination"
}

append_shell_if_missing() {
    local shell_path="$1"

    touch /etc/shells
    if ! grep -Fxq "$shell_path" /etc/shells; then
        log "Adding $shell_path to /etc/shells"
        local backup="/etc/shells.linux-cli-setup.${TIMESTAMP}.bak"
        run_step "Backing up" "/etc/shells" cp -p /etc/shells "$backup"
        record_rollback_cmd "mv -f $(shell_quote "$backup") /etc/shells"
        printf '%s\n' "$shell_path" >> /etc/shells
    fi
}

required_packages_for_profile() {
    local family="$1"
    local profile="$2"

    case "$family:$profile" in
        arch:core)
            printf '%s\n' base-devel ca-certificates curl wget gnupg git openssh fish htop btop unzip zip p7zip tar gzip xz tmux fontconfig
            ;;
        debian:core)
            printf '%s\n' ca-certificates curl wget gnupg git openssh-server fish htop btop unzip zip p7zip-full tar gzip xz-utils tmux fontconfig systemd-timesyncd
            ;;
        arch:docker)
            printf '%s\n' docker docker-compose
            ;;
        debian:docker)
            printf '%s\n' docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io
            ;;
        *)
            return 0
            ;;
    esac
}

recommended_packages_for_profile() {
    local family="$1"
    local profile="$2"

    case "$family:$profile" in
        arch:core)
            printf '%s\n' ripgrep fd fzf plocate bat eza tree less jq yq ncdu duf dust lnav man-db man-pages tldr fastfetch inxi git-delta pacman-contrib reflector pkgfile chezmoi
            ;;
        debian:core)
            printf '%s\n' ripgrep fd-find fzf plocate bat eza tree less jq yq ncdu duf lnav man-db manpages tldr fastfetch inxi git-delta apt-file needrestart debian-goodies software-properties-common apt-transport-https unattended-upgrades nala chezmoi
            ;;
        arch:dev)
            printf '%s\n' python python-pip python-pipx uv base-devel cmake pkgconf neovim
            ;;
        debian:dev)
            printf '%s\n' python3 python3-pip python3-venv pipx build-essential cmake pkg-config neovim
            ;;
        arch:netops)
            printf '%s\n' bind iproute2 iputils traceroute mtr tcpdump wireshark-cli nmap iperf3 ethtool lsof whois openbsd-netcat socat arp-scan smbclient net-snmp wireguard-tools openvpn mosh sshfs rsync rclone fail2ban
            ;;
        debian:netops)
            printf '%s\n' dnsutils iproute2 iputils-ping traceroute mtr-tiny tcpdump tshark nmap iperf3 ethtool lsof whois netcat-openbsd socat arp-scan smbclient snmp snmp-mibs-downloader wireguard-tools openvpn mosh sshfs rsync rclone fail2ban
            ;;
        arch:diagnostics)
            printf '%s\n' pciutils usbutils lshw dmidecode lm_sensors smartmontools nvme-cli parted gptfdisk iotop sysstat iftop nethogs strace lsof psmisc
            ;;
        debian:diagnostics)
            printf '%s\n' pciutils usbutils lshw dmidecode lm-sensors smartmontools nvme-cli parted gdisk iotop sysstat iftop nethogs strace lsof psmisc
            ;;
        arch:docker)
            printf '%s\n' lazydocker dive ctop hadolint
            ;;
        debian:docker)
            printf '%s\n' lazydocker dive ctop hadolint
            ;;
        arch:desktop)
            printf '%s\n' xclip wl-clipboard xsel xdg-utils libnotify
            ;;
        debian:desktop)
            printf '%s\n' xclip wl-clipboard xsel xdg-utils libnotify-bin
            ;;
        *)
            return 0
            ;;
    esac
}

package_is_installed() {
    local package="$1"

    case "$PACKAGE_FAMILY" in
        debian)
            dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'
            ;;
        arch)
            pacman -Q "$package" >/dev/null 2>&1
            ;;
        *)
            return 1
            ;;
    esac
}

record_package_install_rollback() {
    local package="$1"

    case "$PACKAGE_FAMILY" in
        debian)
            record_rollback_cmd "DEBIAN_FRONTEND=noninteractive apt-get remove -y $(shell_quote "$package")"
            ;;
        arch)
            record_rollback_cmd "pacman -Rns --noconfirm $(shell_quote "$package")"
            ;;
    esac
}

install_debian_package() {
    local package="$1"
    local required="$2"
    local was_installed=0

    package_is_installed "$package" && was_installed=1
    export DEBIAN_FRONTEND=noninteractive

    if run_step "${PACKAGE_STEP_VERB:-Installing}" "apt package $package" apt-get install -y --no-install-recommends "$package"; then
        [[ "$was_installed" -eq 0 ]] && record_package_install_rollback "$package"
        return 0
    fi

    [[ "$required" == "1" ]] && return 1
    warn "Could not install optional apt package '$package'. It may not be available for this release."
    return 0
}

install_arch_package() {
    local package="$1"
    local required="$2"
    local was_installed=0

    package_is_installed "$package" && was_installed=1

    if run_step "${PACKAGE_STEP_VERB:-Installing}" "pacman package $package" pacman -S --needed --noconfirm "$package"; then
        [[ "$was_installed" -eq 0 ]] && record_package_install_rollback "$package"
        return 0
    fi

    if [[ "$required" != "1" && -x "$(command -v yay 2>/dev/null || true)" ]]; then
        if run_step_optional "${PACKAGE_STEP_VERB:-Installing}" "AUR package $package" run_as_target yay -S --needed --noconfirm "$package"; then
            [[ "$was_installed" -eq 0 ]] && record_package_install_rollback "$package"
            return 0
        fi
    fi

    [[ "$required" == "1" ]] && return 1
    warn "Could not install optional Arch package '$package'. It may not be available in pacman or AUR."
    return 0
}

install_debian_required_packages() {
    local package

    export DEBIAN_FRONTEND=noninteractive
    for package in "$@"; do
        install_debian_package "$package" 1
    done
}

install_debian_recommended_packages() {
    local package

    export DEBIAN_FRONTEND=noninteractive
    for package in "$@"; do
        install_debian_package "$package" 0
    done
}

install_arch_required_packages() {
    local package

    for package in "$@"; do
        install_arch_package "$package" 1
    done
}

install_arch_recommended_packages() {
    local package

    for package in "$@"; do
        install_arch_package "$package" 0
    done
}

install_profile_packages() {
    local profile="$1"
    local required_packages=()
    local recommended_packages=()

    mapfile -t required_packages < <(required_packages_for_profile "$PACKAGE_FAMILY" "$profile")
    mapfile -t recommended_packages < <(recommended_packages_for_profile "$PACKAGE_FAMILY" "$profile")

    case "$PACKAGE_FAMILY" in
        debian)
            install_debian_required_packages "${required_packages[@]}"
            install_debian_recommended_packages "${recommended_packages[@]}"
            ;;
        arch)
            install_arch_required_packages "${required_packages[@]}"
            install_arch_recommended_packages "${recommended_packages[@]}"
            ;;
        *)
            die "Unsupported package family: $PACKAGE_FAMILY"
            ;;
    esac
}

update_package_database_and_system() {
    case "$PACKAGE_FAMILY" in
        debian)
            export DEBIAN_FRONTEND=noninteractive
            run_step "Updating" "apt package indexes" apt-get update
            run_step "Updating" "apt system packages" apt-get -y upgrade
            ;;
        arch)
            run_step "Updating" "pacman package database and system packages" pacman -Syu --noconfirm
            ;;
        *)
            die "Unsupported package family: $PACKAGE_FAMILY"
            ;;
    esac
}

ensure_yay_on_arch() {
    if [[ "$PACKAGE_FAMILY" != "arch" ]]; then
        return
    fi

    if command -v yay >/dev/null 2>&1; then
        log "yay is already installed"
        return
    fi

    log "Installing yay-bin from the Arch User Repository"
    install_arch_required_packages base-devel git ca-certificates curl

    local build_root
    build_root="$(mktemp -d)"
    chown "$TARGET_USER:$TARGET_GROUP" "$build_root"
    record_rollback_cmd "rm -rf $(shell_quote "$build_root")"

    run_step "Downloading" "yay-bin AUR repository" run_as_target git clone https://aur.archlinux.org/yay-bin.git "$build_root/yay-bin"
    run_step "Building" "yay-bin package" run_as_target bash -lc "cd '$build_root/yay-bin' && makepkg -s --noconfirm"

    local package_file
    package_file="$(find "$build_root/yay-bin" -maxdepth 1 -type f -name 'yay-bin-*.pkg.tar.*' | head -n 1)"
    [[ -n "$package_file" ]] || die "yay package build completed but no package file was found."

    run_step "Installing" "yay-bin package" pacman -U --noconfirm "$package_file"
    record_rollback_cmd "pacman -Rns --noconfirm yay-bin yay"
    rm -rf "$build_root"
}

install_jetbrains_nerd_font_from_package_or_release() {
    if fc-match 'JetBrainsMono Nerd Font Mono' 2>/dev/null | grep -qi 'JetBrains'; then
        log "JetBrainsMono Nerd Font Mono is already available"
        return
    fi

    if [[ "$PACKAGE_FAMILY" == "arch" ]]; then
        local font_was_installed=0
        package_is_installed ttf-jetbrains-mono-nerd && font_was_installed=1
        if run_step_optional "Installing" "pacman package ttf-jetbrains-mono-nerd" pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd; then
            [[ "$font_was_installed" -eq 0 ]] && record_package_install_rollback ttf-jetbrains-mono-nerd
            fc-cache -f >/dev/null 2>&1 || true
            return
        fi
        log "Arch package install failed; falling back to the Nerd Fonts release archive"
    fi

    local font_dir="/usr/local/share/fonts/JetBrainsMonoNerdFont"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    record_rollback_cmd "rm -rf $(shell_quote "$tmp_dir")"

    log "Installing JetBrainsMono Nerd Font Mono from the latest Nerd Fonts release"
    run_step "Downloading" "JetBrainsMono Nerd Font Mono" curl -fsSL \
        --output "$tmp_dir/JetBrainsMono.tar.xz" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz"

    if [[ -e "$font_dir" ]]; then
        backup_existing_path "$font_dir"
    else
        record_rollback_cmd "rm -rf $(shell_quote "$font_dir")"
    fi
    run_step "Creating directory" "$font_dir" mkdir -p "$font_dir"
    run_step "Installing" "JetBrainsMono Nerd Font files" tar -xJf "$tmp_dir/JetBrainsMono.tar.xz" -C "$font_dir"
    run_step "Cleaning" "non-font files from JetBrainsMono Nerd Font" find "$font_dir" -type f ! \( -name '*.ttf' -o -name '*.otf' \) -delete
    run_step "Setting permissions" "$font_dir" chmod -R a+rX "$font_dir"
    run_step_optional "Updating" "font cache" fc-cache -f "$font_dir"
    rm -rf "$tmp_dir"
}

enable_openssh_service() {
    if ! systemd_available; then
        log "systemctl is unavailable; skipping OpenSSH service enablement"
        return
    fi

    if systemctl list-unit-files --no-legend ssh.service 2>/dev/null | grep -q '^ssh\.service'; then
        log "Enabling and starting ssh.service"
        run_step "Enabling service" "ssh.service" systemctl enable --now ssh.service
        return
    fi

    if systemctl list-unit-files --no-legend sshd.service 2>/dev/null | grep -q '^sshd\.service'; then
        log "Enabling and starting sshd.service"
        run_step "Enabling service" "sshd.service" systemctl enable --now sshd.service
        return
    fi

    log "OpenSSH service unit was not found; package install may have used a non-systemd layout"
}

configure_git_defaults() {
    log "Applying Git defaults for $TARGET_USER"
    run_step "Configuring" "Git init.defaultBranch" run_as_target git config --global init.defaultBranch main
    run_step "Configuring" "Git pull.ff" run_as_target git config --global pull.ff only
    run_step "Configuring" "Git fetch.prune" run_as_target git config --global fetch.prune true
    run_step "Configuring" "Git merge.conflictstyle" run_as_target git config --global merge.conflictstyle zdiff3
    run_step "Configuring" "Git rerere.enabled" run_as_target git config --global rerere.enabled true
    run_step "Configuring" "Git core.editor" run_as_target git config --global core.editor nvim

    if run_as_target bash -lc 'command -v delta >/dev/null 2>&1'; then
        run_step "Configuring" "Git delta pager" run_as_target git config --global core.pager delta
        run_step "Configuring" "Git delta diff filter" run_as_target git config --global interactive.diffFilter 'delta --color-only'
        run_step "Configuring" "Git delta navigation" run_as_target git config --global delta.navigate true
        run_step "Configuring" "Git delta side-by-side" run_as_target git config --global delta.side-by-side true
    fi
}

configure_fish_files() {
    local fish_config_dir="$TARGET_HOME/.config/fish"

    log "Installing Fish configuration for $TARGET_USER"
    install -o "$TARGET_USER" -g "$TARGET_GROUP" -d "$fish_config_dir" "$fish_config_dir/conf.d"
    install_owned_file "$FISH_TEMPLATE_DIR/config.fish" "$fish_config_dir/config.fish" 0644 "$TARGET_USER" "$TARGET_GROUP"
    install_owned_file "$FISH_TEMPLATE_DIR/fish_plugins" "$fish_config_dir/fish_plugins" 0644 "$TARGET_USER" "$TARGET_GROUP"
}

install_fisher_plugins() {
    local plugin_list
    plugin_list="$(grep -Ev '^[[:space:]]*(#|$)' "$FISH_TEMPLATE_DIR/fish_plugins" | tr '\n' ' ')"

    log "Installing or updating Fisher and Fish plugins for $TARGET_USER"
    run_step "Installing" "Fisher and Fish plugins" run_as_target fish -lc "curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; and fisher install jorgebucaran/fisher; and fisher install $plugin_list"

    log "Applying Tide prompt settings"
    run_step "Configuring" "Tide prompt" run_as_target fish "$FISH_TEMPLATE_DIR/configure_tide.fish"
}

update_fisher_plugins() {
    if ! command -v fish >/dev/null 2>&1; then
        warn "Fish is not installed; skipping Fisher plugin update"
        return
    fi

    log "Updating Fisher plugins for $TARGET_USER"
    run_step "Updating" "Fisher plugins" run_as_target fish -lc 'if functions -q fisher; fisher update; else exit 0; end'
    run_step "Configuring" "Tide prompt" run_as_target fish "$FISH_TEMPLATE_DIR/configure_tide.fish"
}

set_default_shell() {
    local fish_path
    fish_path="$(command -v fish || true)"
    [[ -n "$fish_path" ]] || die "fish was installed, but no fish executable was found in PATH."

    append_shell_if_missing "$fish_path"

    log "Changing $TARGET_USER default shell to $fish_path"
    record_rollback_cmd "chsh -s $(shell_quote "$ORIGINAL_SHELL") $(shell_quote "$TARGET_USER") 2>/dev/null || usermod --shell $(shell_quote "$ORIGINAL_SHELL") $(shell_quote "$TARGET_USER")"
    if command -v chsh >/dev/null 2>&1; then
        run_step "Changing shell" "$TARGET_USER to $fish_path" chsh -s "$fish_path" "$TARGET_USER"
    else
        run_step "Changing shell" "$TARGET_USER to $fish_path" usermod --shell "$fish_path" "$TARGET_USER"
    fi
}

install_motd() {
    log "Installing dynamic MOTD script"
    install_owned_file "$MOTD_TEMPLATE" /usr/local/bin/linux-cli-motd 0755 root root

    if [[ -d /etc/update-motd.d ]]; then
        local state_dir="/etc/update-motd.d/.linux-cli-setup-disabled"
        run_step "Creating directory" "$state_dir" mkdir -p "$state_dir"

        log "Installing /etc/update-motd.d/50-linux-cli-setup"
        install_owned_file "$MOTD_TEMPLATE" /etc/update-motd.d/50-linux-cli-setup 0755 root root

        if [[ "${LINUX_CLI_KEEP_DEFAULT_MOTD:-0}" != "1" ]]; then
            log "Disabling other executable update-motd snippets; set LINUX_CLI_KEEP_DEFAULT_MOTD=1 to keep them enabled"
            while IFS= read -r -d '' motd_file; do
                [[ "$(basename "$motd_file")" == "50-linux-cli-setup" ]] && continue
                run_step "Disabling MOTD snippet" "$motd_file" chmod a-x "$motd_file"
                record_rollback_cmd "chmod a+x $(shell_quote "$motd_file")"
                printf '%s\n' "$motd_file" >> "$state_dir/disabled-${TIMESTAMP}.txt"
            done < <(find /etc/update-motd.d -maxdepth 1 -type f -perm /111 -print0)
        fi

        return
    fi

    log "No /etc/update-motd.d directory found; installing Fish login MOTD hook"
    run_step "Creating directory" "/etc/fish/conf.d" install -m 0755 -d /etc/fish/conf.d
    install_owned_file "$FISH_TEMPLATE_DIR/conf.d/linux-cli-motd.fish" /etc/fish/conf.d/linux-cli-motd.fish 0644 root root
}

enable_arch_helpers() {
    if [[ "$PACKAGE_FAMILY" != "arch" ]]; then
        return
    fi

    if systemd_available && systemctl list-unit-files --no-legend paccache.timer 2>/dev/null | grep -q '^paccache\.timer'; then
        log "Enabling paccache.timer"
        run_step_optional "Enabling timer" "paccache.timer" systemctl enable --now paccache.timer
    fi

    if command -v pkgfile >/dev/null 2>&1; then
        log "Updating pkgfile database"
        run_step_optional "Updating" "pkgfile database" pkgfile -u
    fi
}

enable_docker_service_and_group() {
    if systemd_available && systemctl list-unit-files --no-legend docker.service 2>/dev/null | grep -q '^docker\.service'; then
        log "Enabling and starting docker.service"
        run_step "Enabling service" "docker.service" systemctl enable --now docker.service
    fi

    if getent group docker >/dev/null 2>&1; then
        log "Adding $TARGET_USER to the docker group"
        if ! id -nG "$TARGET_USER" | tr ' ' '\n' | grep -Fxq docker; then
            record_rollback_cmd "gpasswd -d $(shell_quote "$TARGET_USER") docker"
        fi
        run_step "Configuring group" "$TARGET_USER in docker" usermod -aG docker "$TARGET_USER"
    fi
}

install_debian_docker_official() {
    local docker_os=""
    local docker_suite=""
    local arch

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" == "ubuntu" ]]; then
        docker_os="ubuntu"
        docker_suite="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    elif [[ "${ID:-}" == "debian" ]]; then
        docker_os="debian"
        docker_suite="${VERSION_CODENAME:-}"
    elif [[ -n "${UBUNTU_CODENAME:-}" ]]; then
        docker_os="ubuntu"
        docker_suite="$UBUNTU_CODENAME"
    fi

    [[ -n "$docker_os" && -n "$docker_suite" ]] || return 1

    export DEBIAN_FRONTEND=noninteractive
    install_debian_required_packages ca-certificates curl gnupg
    run_step "Creating directory" "/etc/apt/keyrings" install -m 0755 -d /etc/apt/keyrings
    run_step "Downloading" "Docker apt signing key" curl -fsSL "https://download.docker.com/linux/$docker_os/gpg" -o /etc/apt/keyrings/docker.asc.tmp
    install_owned_file /etc/apt/keyrings/docker.asc.tmp /etc/apt/keyrings/docker.asc 0644 root root
    rm -f /etc/apt/keyrings/docker.asc.tmp

    arch="$(dpkg --print-architecture)"
    local docker_sources_tmp
    docker_sources_tmp="$(mktemp)"
    {
        printf 'Types: deb\n'
        printf 'URIs: https://download.docker.com/linux/%s\n' "$docker_os"
        printf 'Suites: %s\n' "$docker_suite"
        printf 'Components: stable\n'
        printf 'Architectures: %s\n' "$arch"
        printf 'Signed-By: /etc/apt/keyrings/docker.asc\n'
    } > "$docker_sources_tmp"
    install_owned_file "$docker_sources_tmp" /etc/apt/sources.list.d/docker.sources 0644 root root
    rm -f "$docker_sources_tmp"

    run_step "Updating" "apt package indexes for Docker repository" apt-get update
    install_debian_required_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

install_debian_docker_fallback() {
    warn "Docker's official apt repository is not supported for this release; falling back to distro Docker packages."
    install_debian_required_packages docker.io
    install_debian_recommended_packages docker-compose-plugin
}

install_docker_profile() {
    local docker_recommended=()

    case "$PACKAGE_FAMILY" in
        arch)
            install_profile_packages docker
            ;;
        debian)
            if [[ "${LINUX_CLI_DOCKER_APT_SOURCE:-official}" == "distro" ]]; then
                install_debian_required_packages docker.io
                install_debian_recommended_packages docker-compose-plugin
            elif ! install_debian_docker_official; then
                install_debian_docker_fallback
            fi
            mapfile -t docker_recommended < <(recommended_packages_for_profile debian docker)
            install_debian_recommended_packages "${docker_recommended[@]}"
            ;;
        *)
            die "Unsupported package family: $PACKAGE_FAMILY"
            ;;
    esac

    enable_docker_service_and_group
}

install_dev_tools() {
    local tool
    local tools=(ruff black pytest pre-commit)

    if ! command -v pipx >/dev/null 2>&1; then
        warn "pipx is not installed; skipping Python tool installation"
        return
    fi

    log "Ensuring pipx user path for $TARGET_USER"
    run_step_optional "Configuring" "pipx user path" run_as_target pipx ensurepath

    if ! command -v uv >/dev/null 2>&1 && ! run_as_target bash -lc 'command -v uv >/dev/null 2>&1'; then
        log "Installing uv with pipx for $TARGET_USER"
        run_step_optional "Installing" "pipx tool uv" run_as_target pipx install uv || run_step_optional "Updating" "pipx tool uv" run_as_target pipx upgrade uv
    fi

    for tool in "${tools[@]}"; do
        log "Installing or upgrading Python tool with pipx: $tool"
        run_step_optional "Installing" "pipx tool $tool" run_as_target pipx install "$tool" || run_step_optional "Updating" "pipx tool $tool" run_as_target pipx upgrade "$tool"
    done
}

update_dev_tools() {
    if ! command -v pipx >/dev/null 2>&1; then
        warn "pipx is not installed; skipping Python tool updates"
        return
    fi

    log "Upgrading pipx-installed Python tools for $TARGET_USER"
    run_step_optional "Updating" "pipx-installed Python tools" run_as_target pipx upgrade-all
}

install_status_commands() {
    install_owned_file "$BIN_TEMPLATE_DIR/time-status" /usr/local/bin/time-status 0755 root root
    install_owned_file "$BIN_TEMPLATE_DIR/ntp-status" /usr/local/bin/ntp-status 0755 root root
}

configure_time_sync() {
    local old_timezone=""
    local old_ntp=""
    local timesync_conf_dir="/etc/systemd/timesyncd.conf.d"
    local timesync_conf_tmp

    old_timezone="$(timedatectl show -p Timezone --value 2>/dev/null || true)"
    old_ntp="$(timedatectl show -p NTP --value 2>/dev/null || true)"

    if [[ -n "$old_timezone" ]]; then
        record_rollback_cmd "timedatectl set-timezone $(shell_quote "$old_timezone")"
    fi
    if [[ -n "$old_ntp" ]]; then
        record_rollback_cmd "timedatectl set-ntp $(shell_quote "$old_ntp")"
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        run_step "Configuring timezone" "America/Detroit" timedatectl set-timezone America/Detroit
        run_step "Configuring NTP" "automatic time synchronization" timedatectl set-ntp true
    else
        [[ -f /etc/localtime ]] && backup_existing_path /etc/localtime
        [[ -f /etc/timezone ]] && backup_existing_path /etc/timezone
        run_step "Configuring timezone" "/etc/localtime" ln -snf /usr/share/zoneinfo/America/Detroit /etc/localtime
        printf '%s\n' "America/Detroit" > /etc/timezone
    fi

    if [[ -d /etc/systemd || -x "$(command -v systemctl 2>/dev/null || true)" ]]; then
        run_step "Creating directory" "$timesync_conf_dir" mkdir -p "$timesync_conf_dir"
        timesync_conf_tmp="$(mktemp)"
        {
            printf '[Time]\n'
            printf '# DHCP-provided NTP servers remain preferred by systemd-timesyncd.\n'
            printf '# This pool is used when no link-specific DHCP NTP server is available.\n'
            printf 'FallbackNTP=us.pool.ntp.org\n'
        } > "$timesync_conf_tmp"
        install_owned_file "$timesync_conf_tmp" "$timesync_conf_dir/10-linux-cli-setup.conf" 0644 root root
        rm -f "$timesync_conf_tmp"

        if systemd_available && systemctl list-unit-files --no-legend systemd-timesyncd.service 2>/dev/null | grep -q '^systemd-timesyncd\.service'; then
            run_step "Enabling service" "systemd-timesyncd.service" systemctl enable --now systemd-timesyncd.service
            run_step_optional "Restarting service" "systemd-timesyncd.service" systemctl restart systemd-timesyncd.service
        fi
    else
        warn "systemd-timesyncd is unavailable; automatic NTP could not be configured by this script."
    fi
}

install_auto_update_config() {
    local config_tmp

    run_step "Creating directory" "$CONFIG_DIR" install -m 0700 -d "$CONFIG_DIR"

    if [[ -f "$AUTO_UPDATE_CONFIG" ]]; then
        run_step "Securing file" "$AUTO_UPDATE_CONFIG" chmod 0600 "$AUTO_UPDATE_CONFIG"
        return
    fi

    config_tmp="$(mktemp)"
    sed \
        -e "s|^AUR_USER=.*|AUR_USER=\"${TARGET_USER}\"|" \
        -e "s|^PUSHOVER_USER_KEY=.*|PUSHOVER_USER_KEY=\"${PUSHOVER_USER_KEY:-}\"|" \
        -e "s|^PUSHOVER_API_TOKEN=.*|PUSHOVER_API_TOKEN=\"${PUSHOVER_API_TOKEN:-}\"|" \
        "$AUTO_UPDATE_TEMPLATE_DIR/auto-update.conf" > "$config_tmp"

    install_owned_file "$config_tmp" "$AUTO_UPDATE_CONFIG" 0600 root root
    rm -f "$config_tmp"
}

install_cron_fallback_if_needed() {
    case "$PACKAGE_FAMILY" in
        debian)
            install_debian_required_packages cron
            ;;
        arch)
            install_arch_required_packages cronie
            ;;
    esac

    install_owned_file "$CRON_TEMPLATE_DIR/linux-cli-auto-update" /etc/cron.d/linux-cli-auto-update 0644 root root

    if systemd_available; then
        if systemctl list-unit-files --no-legend cron.service 2>/dev/null | grep -q '^cron\.service'; then
            run_step_optional "Enabling service" "cron.service" systemctl enable --now cron.service
        elif systemctl list-unit-files --no-legend cronie.service 2>/dev/null | grep -q '^cronie\.service'; then
            run_step_optional "Enabling service" "cronie.service" systemctl enable --now cronie.service
        fi
    fi
}

install_auto_update_service() {
    install_auto_update_config
    install_owned_file "$AUTO_UPDATE_TEMPLATE_DIR/linux-cli-auto-update" /usr/local/sbin/linux-cli-auto-update 0755 root root

    if systemd_available; then
        install_owned_file "$SYSTEMD_TEMPLATE_DIR/linux-cli-auto-update.service" /etc/systemd/system/linux-cli-auto-update.service 0644 root root
        install_owned_file "$SYSTEMD_TEMPLATE_DIR/linux-cli-auto-update.timer" /etc/systemd/system/linux-cli-auto-update.timer 0644 root root
        run_step "Reloading" "systemd manager configuration" systemctl daemon-reload
        run_step "Enabling timer" "linux-cli-auto-update.timer" systemctl enable --now linux-cli-auto-update.timer
        return
    fi

    warn "systemd is unavailable; installing cron fallback for automatic updates."
    install_cron_fallback_if_needed
}

profile_is_selected() {
    local wanted="$1"
    local profile

    for profile in "${SELECTED_PROFILES[@]}"; do
        [[ "$profile" == "$wanted" ]] && return 0
    done

    return 1
}

remove_file_if_managed_or_backup() {
    local installed_path="$1"
    local template_path="$2"

    if [[ ! -e "$installed_path" && ! -L "$installed_path" ]]; then
        return
    fi

    if [[ -f "$template_path" && -f "$installed_path" ]]; then
        if cmp -s "$template_path" "$installed_path"; then
            log "Removing managed file $installed_path"
            run_step_optional "Removing file" "$installed_path" rm -f "$installed_path"
            return
        fi
    fi

    local backup="${installed_path}.linux-cli-setup.uninstall.${TIMESTAMP}.bak"
    warn "$installed_path differs from the project template; moving it to $backup instead of deleting it."
    run_step_optional "Backing up changed file" "$installed_path" mv "$installed_path" "$backup"
}

remove_profile_packages() {
    local profile="$1"
    local packages=()

    mapfile -t packages < <(
        required_packages_for_profile "$PACKAGE_FAMILY" "$profile"
        recommended_packages_for_profile "$PACKAGE_FAMILY" "$profile"
    )

    [[ "${#packages[@]}" -gt 0 ]] || return 0

    case "$PACKAGE_FAMILY" in
        debian)
            export DEBIAN_FRONTEND=noninteractive
            for package in "${packages[@]}"; do
                if package_is_installed "$package"; then
                    run_step_optional "Uninstalling" "apt package $package" apt-get remove -y "$package"
                else
                    log "Skipping absent apt package $package"
                fi
            done
            ;;
        arch)
            for package in "${packages[@]}"; do
                if package_is_installed "$package"; then
                    run_step_optional "Uninstalling" "pacman package $package" pacman -Rns --noconfirm "$package"
                else
                    log "Skipping absent pacman package $package"
                fi
            done
            ;;
        *)
            die "Unsupported package family: $PACKAGE_FAMILY"
            ;;
    esac
}
