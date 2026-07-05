#!/usr/bin/env bash
#
# Shared helpers for linux-cli-setup install, refresh, and uninstall scripts.

set -Eeuo pipefail

COMMON_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$COMMON_SCRIPT_DIR/../.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION"
FISH_TEMPLATE_DIR="$PROJECT_ROOT/templates/fish"
SSH_TEMPLATE_DIR="$PROJECT_ROOT/templates/ssh"
SYSCTL_TEMPLATE_DIR="$PROJECT_ROOT/templates/sysctl"
APT_TEMPLATE_DIR="$PROJECT_ROOT/templates/apt"
MOTD_TEMPLATE="$PROJECT_ROOT/templates/motd/linux-cli-motd"
AUTO_UPDATE_TEMPLATE_DIR="$PROJECT_ROOT/templates/auto-update"
CHRONY_TEMPLATE_DIR="$PROJECT_ROOT/templates/chrony"
FAIL2BAN_TEMPLATE_DIR="$PROJECT_ROOT/templates/fail2ban"
LOGROTATE_TEMPLATE_DIR="$PROJECT_ROOT/templates/logrotate"
BIN_TEMPLATE_DIR="$PROJECT_ROOT/templates/bin"
SYSTEMD_TEMPLATE_DIR="$PROJECT_ROOT/templates/systemd"
CRON_TEMPLATE_DIR="$PROJECT_ROOT/templates/cron"
PACKAGE_GROUPS_FILE="$PROJECT_ROOT/data/package-groups.tsv"
STATE_DIR="/var/lib/linux-cli-setup"
STATE_FILE="$STATE_DIR/install.env"
CONFIG_DIR="/etc/linux-cli-setup"
AUTO_UPDATE_CONFIG="/etc/linux-cli-setup/auto-update.conf"
LOG_DIR="/var/log/linux-cli-setup"
TIMESTAMP="$(date +%Y%m%d%H%M%S)"
EXPECTED_GITHUB_REPO="${LINUX_CLI_SELF_UPDATE_REPO:-cosmicc/linux-cli-setup}"
SELF_UPDATE_BRANCH="${LINUX_CLI_SELF_UPDATE_BRANCH:-main}"

SUPPORTED_PROFILES=(core comfort dev netops wireless storage diagnostics docker desktop)
COMFORT_FISH_FUNCTIONS=(mkcd extract dnscheck certcheck serve jfu scs)
WIRELESS_FISH_FUNCTIONS=(wifi-connect wifi-info)
SELECTED_PROFILES=()
PROFILES_EXPLICIT=0
PROFILE_POSITIONAL_ARGS=()
SKIP_PERFORMANCE_TUNING="${LINUX_CLI_SKIP_PERFORMANCE:-0}"
SKIP_HARDENING="${LINUX_CLI_SKIP_HARDENING:-0}"
# INSTALL_MODE is set by setup-linux-cli.sh after this shared library is sourced.
# shellcheck disable=SC2034
INSTALL_MODE=install
DEBUG=0
USE_COLOR=1
LOG_FILE=""
CURRENT_STEP_OUTPUT=""
ROLLBACK_FILE=""
ROLLBACK_ENABLED=0
ROLLBACK_RUNNING=0
SELF_UPDATE_RUN_USER=""

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

init_logging_with_user_fallback() {
    local action="$1"
    local fallback_log_dir="$PROJECT_ROOT/logs"

    if install -m 0755 -d "$LOG_DIR" >/dev/null 2>&1; then
        LOG_FILE="$LOG_DIR/${action}-${TIMESTAMP}.log"
        touch "$LOG_FILE"
        chmod 0644 "$LOG_FILE"
    else
        mkdir -p "$fallback_log_dir"
        LOG_FILE="$fallback_log_dir/${action}-${TIMESTAMP}.log"
        touch "$LOG_FILE"
        chmod 0644 "$LOG_FILE"
    fi

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

trim_string() {
    local value="$1"

    value="${value//$'\r'/}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
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

    printf '0.4a'
}

print_version() {
    printf 'linux-cli-setup %s\n' "$(project_version)"
}

version_sort_key() {
    local raw="$1"
    local suffix=""
    local suffix_name=""
    local suffix_number=0
    local stage_rank=3
    local major=0
    local minor=0
    local patch=0

    raw="${raw#v}"
    raw="${raw#V}"

    if [[ "$raw" =~ ^([0-9]+)(\.([0-9]+))?(\.([0-9]+))?([[:alpha:]]+[0-9]*)?$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[3]:-0}"
        patch="${BASH_REMATCH[5]:-0}"
        suffix="${BASH_REMATCH[6]:-}"
    else
        return 1
    fi

    if [[ -n "$suffix" ]]; then
        suffix_name="${suffix//[0-9]/}"
        suffix_number="${suffix//[!0-9]/}"
        suffix_number="${suffix_number:-0}"

        case "${suffix_name,,}" in
            a|alpha)
                stage_rank=0
                ;;
            b|beta)
                stage_rank=1
                ;;
            rc)
                stage_rank=2
                ;;
            *)
                stage_rank=2
                ;;
        esac
    fi

    printf '%06d.%06d.%06d.%02d.%06d\n' \
        "$major" "$minor" "$patch" "$stage_rank" "$suffix_number"
}

version_is_newer() {
    local candidate="$1"
    local current="$2"
    local candidate_key
    local current_key

    candidate_key="$(version_sort_key "$candidate")" || return 1
    current_key="$(version_sort_key "$current")" || return 1

    [[ "$candidate_key" > "$current_key" ]]
}

github_repo_from_remote_url() {
    local remote_url="$1"
    local repo=""

    case "$remote_url" in
        https://github.com/*)
            repo="${remote_url#https://github.com/}"
            ;;
        git@github.com:*)
            repo="${remote_url#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            repo="${remote_url#ssh://git@github.com/}"
            ;;
        *)
            return 1
            ;;
    esac

    repo="${repo%.git}"
    repo="${repo%%/*/*/*}"
    printf '%s\n' "$repo"
}

detect_self_update_run_user() {
    local owner=""

    owner="$(stat -c '%U' "$PROJECT_ROOT/.git" 2>/dev/null || true)"
    if [[ -n "$owner" && "$owner" != "root" && "$owner" != "UNKNOWN" ]] && id "$owner" >/dev/null 2>&1; then
        printf '%s\n' "$owner"
    fi
}

self_update_command() {
    local run_home

    if [[ -n "${SELF_UPDATE_RUN_USER:-}" ]]; then
        run_home="$(getent passwd "$SELF_UPDATE_RUN_USER" | cut -d: -f6)"
        runuser -u "$SELF_UPDATE_RUN_USER" -- env \
            HOME="$run_home" \
            USER="$SELF_UPDATE_RUN_USER" \
            LOGNAME="$SELF_UPDATE_RUN_USER" \
            "$@"
        return
    fi

    "$@"
}

release_tags_from_github_cli() {
    local repo_slug="$1"

    command -v gh >/dev/null 2>&1 || return 1
    self_update_command gh release list \
        --repo "$repo_slug" \
        --limit 100 \
        --json tagName,isDraft \
        --jq '.[] | select(.isDraft == false) | .tagName' 2>/dev/null
}

release_tags_from_git_remote() {
    local remote="$1"

    self_update_command git -C "$PROJECT_ROOT" ls-remote --tags --refs "$remote" 'v*' '[0-9]*' 2>/dev/null |
        awk '{ sub("^refs/tags/", "", $2); print $2 }'
}

newest_version_tag_from_list() {
    local tag
    local version
    local newest_tag=""
    local newest_version=""

    while IFS= read -r tag; do
        tag="$(trim_string "$tag")"
        [[ -n "$tag" ]] || continue
        version="${tag#v}"
        version="${version#V}"
        version_sort_key "$version" >/dev/null || continue

        if [[ -z "$newest_tag" ]] || version_is_newer "$version" "$newest_version"; then
            newest_tag="$tag"
            newest_version="$version"
        fi
    done

    [[ -n "$newest_tag" ]] || return 1
    printf '%s\n' "$newest_tag"
}

latest_github_release_tag() {
    local remote="$1"
    local remote_url="$2"
    local repo_slug
    local tag_list

    repo_slug="$(github_repo_from_remote_url "$remote_url" || true)"
    [[ -n "$repo_slug" ]] || return 1

    tag_list="$(release_tags_from_github_cli "$repo_slug" || true)"
    if [[ -n "$tag_list" ]]; then
        newest_version_tag_from_list <<< "$tag_list"
        return
    fi

    tag_list="$(release_tags_from_git_remote "$remote" || true)"
    [[ -n "$tag_list" ]] || return 1
    newest_version_tag_from_list <<< "$tag_list"
}

run_visible_self_update_step() {
    local action="$1"
    shift
    local rc=0

    console_line blue "[linux-cli-setup] ${action}"
    debug "Command: $*"

    if [[ -n "$LOG_FILE" ]]; then
        self_update_command "$@" 2>&1 | tee -a "$LOG_FILE"
        rc="${PIPESTATUS[0]}"
    else
        self_update_command "$@"
        rc="$?"
    fi

    if [[ "$rc" -ne 0 ]]; then
        error "${action} failed (exit $rc)"
        return "$rc"
    fi

    success "${action} complete"
}

worktree_has_local_changes() {
    ! self_update_command git -C "$PROJECT_ROOT" diff --quiet --ignore-submodules -- ||
        ! self_update_command git -C "$PROJECT_ROOT" diff --cached --quiet --ignore-submodules --
}

create_self_update_restart_wrapper() {
    local entrypoint="$1"
    shift
    local wrapper
    local arg

    wrapper="$(mktemp /tmp/linux-cli-setup-restart.XXXXXX)"
    {
        printf '#!/usr/bin/env bash\n'
        printf 'set -euo pipefail\n'
        printf 'cd %q\n' "$PROJECT_ROOT"
        printf 'export LINUX_CLI_SELF_UPDATE_RESTARTED=1\n'
        printf 'exec %q' "$entrypoint"
        for arg in "$@"; do
            printf ' %q' "$arg"
        done
        printf '\n'
    } > "$wrapper"
    chmod 0700 "$wrapper"
    printf '%s\n' "$wrapper"
}

self_update_if_newer() {
    local entrypoint="$1"
    shift || true
    local remote="${LINUX_CLI_SELF_UPDATE_REMOTE:-origin}"
    local remote_url
    local remote_repo
    local current_version
    local latest_tag
    local latest_version
    local restart_wrapper

    [[ "${LINUX_CLI_SKIP_SELF_UPDATE:-0}" != "1" ]] || return 0
    [[ "${LINUX_CLI_SELF_UPDATE_RESTARTED:-0}" != "1" ]] || return 0

    if ! command -v git >/dev/null 2>&1 || [[ ! -d "$PROJECT_ROOT/.git" ]]; then
        warn "Git checkout not available; skipping self-update check."
        return 0
    fi

    SELF_UPDATE_RUN_USER="$(detect_self_update_run_user)"
    if [[ -n "$SELF_UPDATE_RUN_USER" ]]; then
        debug "Running self-update Git commands as $SELF_UPDATE_RUN_USER"
    fi

    remote_url="$(self_update_command git -C "$PROJECT_ROOT" remote get-url "$remote" 2>/dev/null || true)"
    if [[ -z "$remote_url" ]]; then
        warn "Git remote '$remote' is not configured; skipping self-update check."
        return 0
    fi

    remote_repo="$(github_repo_from_remote_url "$remote_url" || true)"
    if [[ "$remote_repo" != "$EXPECTED_GITHUB_REPO" ]]; then
        warn "Remote '$remote' does not point to $EXPECTED_GITHUB_REPO; skipping self-update check."
        return 0
    fi

    log "Checking GitHub releases for a newer linux-cli-setup version."
    current_version="$(project_version)"
    latest_tag="$(latest_github_release_tag "$remote" "$remote_url" || true)"

    if [[ -z "$latest_tag" ]]; then
        warn "Could not find a GitHub release or prerelease tag; continuing with version $current_version."
        return 0
    fi

    latest_version="${latest_tag#v}"
    latest_version="${latest_version#V}"
    if ! version_is_newer "$latest_version" "$current_version"; then
        log "Running version $current_version is current."
        return 0
    fi

    console_line yellow "[linux-cli-setup] New version detected: $latest_version (running $current_version)."
    console_line yellow "[linux-cli-setup] Downloading the newest release from GitHub with progress shown below."

    if worktree_has_local_changes; then
        die "Local tracked changes are present in $PROJECT_ROOT. Commit or stash them before self-updating."
    fi

    run_visible_self_update_step "Downloading release metadata from GitHub" \
        git -C "$PROJECT_ROOT" fetch --progress --tags "$remote" ||
        die "Self-update failed while downloading release metadata."
    run_visible_self_update_step "Pulling latest linux-cli-setup from GitHub" \
        git -C "$PROJECT_ROOT" pull --ff-only --progress "$remote" "$SELF_UPDATE_BRANCH" ||
        die "Self-update failed while pulling the latest release."

    restart_wrapper="$(create_self_update_restart_wrapper "$entrypoint" "$@")"
    console_line yellow "[linux-cli-setup] Restarting the script with linux-cli-setup $latest_version."
    exec "$restart_wrapper"
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

install_state_exists() {
    [[ -f "$STATE_FILE" ]]
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

    return 1
}

unsupported_distribution_message() {
    printf 'Unsupported distribution. install.sh, update.sh, and uninstall.sh must run on an Arch-based system with pacman or a Debian/Ubuntu-based system with apt-get.'
}

require_supported_package_family() {
    die "$(unsupported_distribution_message)"
}

init_package_family() {
    if ! PACKAGE_FAMILY="$(detect_package_family)"; then
        require_supported_package_family
    fi
    export PACKAGE_FAMILY
}

init_runtime_context() {
    TARGET_USER="$(detect_target_user)"
    id "$TARGET_USER" >/dev/null 2>&1 || die "Target user $TARGET_USER does not exist."

    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    TARGET_GROUP="$(id -gn "$TARGET_USER")"
    ORIGINAL_SHELL="$(getent passwd "$TARGET_USER" | cut -d: -f7)"
    if [[ -z "${PACKAGE_FAMILY:-}" ]]; then
        init_package_family
    fi

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
        comfort)
            printf 'CLI workflow helpers, safer shell shortcuts, Fish functions, and SSH client defaults'
            ;;
        dev)
            printf 'Python, C/C++ build tools, Neovim, uv, pipx tools, and developer Git helpers'
            ;;
        netops)
            printf 'DNS, packet capture, port scanning, VPN, SSH, transfer, and MSP troubleshooting tools'
            ;;
        wireless)
            printf 'NetworkManager, Wi-Fi scanning, firmware, RF-kill, mobile broadband, and wireless CLI helpers'
            ;;
        storage)
            printf 'filesystem, removable media, SMB/CIFS, encryption, recovery, and flash-media tools'
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

ensure_core_profile_first() {
    local selected_profile
    local reordered_profiles=(core)

    for selected_profile in "${SELECTED_PROFILES[@]}"; do
        [[ "$selected_profile" == "core" ]] && continue
        reordered_profiles+=("$selected_profile")
    done

    SELECTED_PROFILES=("${reordered_profiles[@]}")
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
            --skip-performance|--skip-performance-tuning)
                SKIP_PERFORMANCE_TUNING=1
                ;;
            --skip-hardening)
                SKIP_HARDENING=1
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
        ensure_core_profile_first
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

package_tier_matches() {
    local row_tier="$1"
    local requested_tier="$2"

    case "$requested_tier" in
        all)
            [[ "$row_tier" == "required" || "$row_tier" == "recommended" || "$row_tier" == "required_distro" || "$row_tier" == "recommended_distro" ]]
            ;;
        *)
            [[ "$row_tier" == "$requested_tier" ]]
            ;;
    esac
}

packages_for_profile_tier() {
    local family="$1"
    local profile="$2"
    local requested_tier="$3"
    local group
    local tier
    local arch_packages
    local debian_packages
    local _notes
    local packages
    local package

    [[ -f "$PACKAGE_GROUPS_FILE" ]] || die "Package group file not found: $PACKAGE_GROUPS_FILE"

    while IFS=$'\t' read -r group tier arch_packages debian_packages _notes || [[ -n "${group:-}" ]]; do
        group="$(trim_string "${group:-}")"
        [[ -z "$group" || "${group:0:1}" == "#" ]] && continue

        tier="$(trim_string "${tier:-}")"
        [[ "$group" == "$profile" ]] || continue
        package_tier_matches "$tier" "$requested_tier" || continue

        case "$family" in
            arch)
                packages="$(trim_string "${arch_packages:-}")"
                ;;
            debian)
                packages="$(trim_string "${debian_packages:-}")"
                ;;
            *)
                die "Unsupported package family: $family"
                ;;
        esac

        [[ -n "$packages" && "$packages" != "-" ]] || continue
        for package in $packages; do
            printf '%s\n' "$package"
        done
    done < "$PACKAGE_GROUPS_FILE" | awk '!seen[$0]++'
}

required_packages_for_profile() {
    packages_for_profile_tier "$1" "$2" required
}

recommended_packages_for_profile() {
    packages_for_profile_tier "$1" "$2" recommended
}

distro_required_packages_for_profile() {
    packages_for_profile_tier "$1" "$2" required_distro
}

distro_recommended_packages_for_profile() {
    packages_for_profile_tier "$1" "$2" recommended_distro
}

all_packages_for_profile() {
    packages_for_profile_tier "$1" "$2" all
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

package_is_available() {
    local package="$1"

    case "$PACKAGE_FAMILY" in
        debian)
            command -v apt-cache >/dev/null 2>&1 || return 1
            apt-cache policy "$package" 2>/dev/null | awk '
                $1 == "Candidate:" {
                    if ($2 == "(none)") {
                        exit 1
                    }
                    found = 1
                }
                END {
                    exit found ? 0 : 1
                }
            '
            ;;
        arch)
            if pacman -Si "$package" >/dev/null 2>&1; then
                return 0
            fi
            if command -v yay >/dev/null 2>&1 && yay -Si "$package" >/dev/null 2>&1; then
                return 0
            fi
            if arch_package_available_in_aur_rpc "$package"; then
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

arch_package_available_in_aur_rpc() {
    local package="$1"

    [[ "$package" =~ ^[A-Za-z0-9@._+-]+$ ]] || return 1
    command -v curl >/dev/null 2>&1 || return 1

    curl -fsSLG --connect-timeout 5 --max-time 10 \
        --data-urlencode v=5 \
        --data-urlencode type=info \
        --data-urlencode "arg[]=$package" \
        https://aur.archlinux.org/rpc/ |
        grep -Eq '"resultcount":[[:space:]]*[1-9]'
}

test_package_availability_for_profiles() {
    local profile
    local package
    local missing_count=0
    local profile_package_count=0
    local total_package_count=0
    local packages=()

    for profile in "${SELECTED_PROFILES[@]}"; do
        mapfile -t packages < <(all_packages_for_profile "$PACKAGE_FAMILY" "$profile")
        if [[ "${#packages[@]}" -eq 0 ]]; then
            warn "No packages are defined for profile '$profile' on $PACKAGE_FAMILY."
            continue
        fi

        profile_package_count=0
        log "Checking package availability for profile: $profile"
        for package in "${packages[@]}"; do
            ((profile_package_count += 1))
            ((total_package_count += 1))
            console_line blue "[linux-cli-setup] Checking package: $profile/$package"
            if package_is_available "$package"; then
                success "Available: $profile/$package"
            else
                warn "Unavailable: $profile/$package"
                ((missing_count += 1))
            fi
        done
        log "Profile $profile package checks complete: $profile_package_count checked."
    done

    if [[ "$missing_count" -gt 0 ]]; then
        warn "$missing_count of $total_package_count package checks were unavailable on this system."
        return 1
    fi

    success "All $total_package_count package checks are available on this system."
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

cleanup_unused_packages_and_cache() {
    local orphan_packages=()

    log "Removing unused packages and cleaning package cache"
    case "$PACKAGE_FAMILY" in
        debian)
            export DEBIAN_FRONTEND=noninteractive
            run_step_optional "Cleaning" "apt unused packages" apt-get autoremove -y || true
            run_step_optional "Cleaning" "apt package cache" apt-get autoclean -y || true
            ;;
        arch)
            if command -v pacman >/dev/null 2>&1; then
                mapfile -t orphan_packages < <(pacman -Qtdq 2>/dev/null || true)
                if [[ "${#orphan_packages[@]}" -gt 0 ]]; then
                    run_step_optional "Cleaning" "pacman orphan packages" pacman -Rns --noconfirm "${orphan_packages[@]}" || true
                else
                    log "No pacman orphan packages found."
                fi

                if command -v paccache >/dev/null 2>&1; then
                    run_step_optional "Cleaning" "pacman package cache" paccache -rk2 || true
                else
                    run_step_optional "Cleaning" "pacman package cache" pacman -Sc --noconfirm || true
                fi
            fi
            ;;
        *)
            warn "Unsupported package family for cleanup: $PACKAGE_FAMILY"
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

    log "Installing yay-bin from the Arch User Repository before profile packages"
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

detected_ssh_ports() {
    local port

    printf '22\n'
    if command -v sshd >/dev/null 2>&1; then
        while IFS= read -r port; do
            [[ "$port" =~ ^[0-9]+$ ]] || continue
            printf '%s\n' "$port"
        done < <(sshd -T 2>/dev/null | awk '$1 == "port" { print $2 }')
    fi
}

ensure_ufw_ping_rule() {
    local rules_file="$1"
    local chain_name="$2"
    local rule_line="$3"
    local tmp_file
    local backup

    [[ -f "$rules_file" ]] || return 0
    if grep -Fq "$rule_line" "$rules_file"; then
        return 0
    fi

    tmp_file="$(mktemp)"
    awk -v rule="$rule_line" '
        /^COMMIT$/ && !added {
            print rule
            added = 1
        }
        { print }
        END {
            if (!added) {
                print rule
            }
        }
    ' "$rules_file" > "$tmp_file"

    backup="${rules_file}.linux-cli-setup.${TIMESTAMP}.bak"
    run_step_optional "Backing up" "$rules_file" cp -p "$rules_file" "$backup" || {
        rm -f "$tmp_file"
        return 0
    }
    record_rollback_cmd "mv -f $(shell_quote "$backup") $(shell_quote "$rules_file")"
    run_step_optional "Allowing" "$chain_name ICMP echo-request" install -m 0644 "$tmp_file" "$rules_file" || true
    rm -f "$tmp_file"
    return 0
}

configure_ufw_firewall() {
    local ssh_port
    local was_active=0

    if ! command -v ufw >/dev/null 2>&1; then
        warn "ufw is not installed; skipping firewall configuration."
        return
    fi

    log "Configuring UFW firewall defaults"
    if ufw status 2>/dev/null | grep -qi '^Status: active'; then
        was_active=1
    fi

    if [[ "$was_active" -eq 0 ]]; then
        record_rollback_cmd "ufw --force disable"
    fi

    run_step_optional "Configuring" "ufw default deny incoming" ufw default deny incoming || true
    run_step_optional "Configuring" "ufw default allow outgoing" ufw default allow outgoing || true

    while IFS= read -r ssh_port; do
        [[ "$ssh_port" =~ ^[0-9]+$ ]] || continue
        run_step_optional "Allowing" "SSH on tcp/$ssh_port" ufw allow "$ssh_port/tcp" || true
    done < <(detected_ssh_ports | awk '!seen[$0]++')

    run_step_optional "Allowing" "iperf3 tcp/5201" ufw allow 5201/tcp || true
    run_step_optional "Allowing" "iperf3 udp/5201" ufw allow 5201/udp || true
    ensure_ufw_ping_rule /etc/ufw/before.rules ufw-before-input '-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT'
    ensure_ufw_ping_rule /etc/ufw/before6.rules ufw6-before-input '-A ufw6-before-input -p ipv6-icmp --icmpv6-type echo-request -j ACCEPT'

    run_step_optional "Enabling" "ufw firewall" ufw --force enable || true
    if systemd_available && systemctl list-unit-files --no-legend ufw.service 2>/dev/null | grep -q '^ufw\.service'; then
        run_step_optional "Enabling service" "ufw.service" systemctl enable --now ufw.service || true
    fi
}

install_owned_file_optional() {
    local source="$1"
    local destination="$2"
    local mode="$3"
    local owner="$4"
    local group="$5"
    local backup

    if [[ -L "$destination" ]]; then
        warn "Skipping optional managed file $destination because it is a symlink."
        return 0
    fi

    run_step_optional "Creating directory" "$(dirname "$destination")" mkdir -p "$(dirname "$destination")" || return 0

    if [[ -e "$destination" ]]; then
        if cmp -s "$source" "$destination"; then
            run_step_optional "Refreshing file" "$destination" install -o "$owner" -g "$group" -m "$mode" "$source" "$destination" || true
            return 0
        fi

        backup="${destination}.linux-cli-setup.${TIMESTAMP}.bak"
        run_step_optional "Backing up" "$destination" cp -p "$destination" "$backup" || return 0
        record_rollback_cmd "cp -p $(shell_quote "$backup") $(shell_quote "$destination")"
    else
        record_rollback_cmd "rm -f $(shell_quote "$destination")"
    fi

    run_step_optional "Installing file" "$destination" install -o "$owner" -g "$group" -m "$mode" "$source" "$destination" || true
    return 0
}

reload_openssh_service_optional() {
    if ! systemd_available; then
        warn "systemd is unavailable; OpenSSH hardening was installed but not reloaded."
        return 0
    fi

    if systemctl list-unit-files --no-legend ssh.service 2>/dev/null | grep -q '^ssh\.service'; then
        run_step_optional "Reloading service" "ssh.service" systemctl reload ssh.service || true
        return 0
    fi

    if systemctl list-unit-files --no-legend sshd.service 2>/dev/null | grep -q '^sshd\.service'; then
        run_step_optional "Reloading service" "sshd.service" systemctl reload sshd.service || true
        return 0
    fi

    warn "OpenSSH service unit was not found; hardening file was installed but the service was not reloaded."
}

sshd_binary() {
    if command -v sshd >/dev/null 2>&1; then
        command -v sshd
        return 0
    fi

    if [[ -x /usr/sbin/sshd ]]; then
        printf '/usr/sbin/sshd\n'
        return 0
    fi

    return 1
}

configure_sshd_hardening() {
    local sshd_template="$SSH_TEMPLATE_DIR/sshd_config.d/90-linux-cli-setup-hardening.conf"
    local sshd_destination="/etc/ssh/sshd_config.d/90-linux-cli-setup-hardening.conf"
    local sshd_command

    log "Hardening: installing OpenSSH daemon guardrails"
    if [[ ! -f "$sshd_template" ]]; then
        warn "Missing OpenSSH hardening template: $sshd_template"
        return 0
    fi

    install_owned_file_optional "$sshd_template" "$sshd_destination" 0644 root root

    if ! sshd_command="$(sshd_binary)"; then
        warn "OpenSSH daemon binary was not found; skipping sshd config validation."
        return 0
    fi

    if run_step_optional "Validating" "OpenSSH daemon configuration" "$sshd_command" -t; then
        reload_openssh_service_optional
        return 0
    fi

    warn "Removing managed OpenSSH hardening snippet because sshd validation failed."
    run_step_optional "Removing file" "$sshd_destination" rm -f "$sshd_destination" || true
}

configure_debian_apt_hardening() {
    local apt_template="$APT_TEMPLATE_DIR/80-linux-cli-setup-hardening"

    [[ "$PACKAGE_FAMILY" == "debian" ]] || return 0

    log "Hardening: configuring apt to reject unauthenticated or insecure repositories"
    if [[ -f "$apt_template" ]]; then
        install_owned_file_optional "$apt_template" /etc/apt/apt.conf.d/80-linux-cli-setup-hardening 0644 root root
    else
        warn "Missing apt hardening template: $apt_template"
    fi
}

apply_basic_os_hardening() {
    local sysctl_template="$SYSCTL_TEMPLATE_DIR/99-linux-cli-setup-hardening.conf"

    log "Hardening: applying kernel, filesystem, network, and login protections"
    if [[ -f "$sysctl_template" ]]; then
        install_owned_file_optional "$sysctl_template" /etc/sysctl.d/99-linux-cli-setup-hardening.conf 0644 root root
        run_step_optional "Applying" "sysctl hardening settings" sysctl --system || true
    else
        warn "Missing sysctl hardening template: $sysctl_template"
    fi

    [[ -d /tmp ]] && run_step_optional "Securing permissions" "/tmp" chmod 1777 /tmp || true
    [[ -d /var/tmp ]] && run_step_optional "Securing permissions" "/var/tmp" chmod 1777 /var/tmp || true
    configure_sshd_hardening
    configure_debian_apt_hardening
}

configure_hardening_section() {
    if [[ "$SKIP_HARDENING" == "1" ]]; then
        log "Skipping hardening section because --skip-hardening was provided."
        return 0
    fi

    log "Hardening: configuring firewall, SSH protection, kernel protections, and safe package-manager defaults"
    configure_ufw_firewall
    configure_fail2ban
    apply_basic_os_hardening
}

configure_performance_tuning() {
    local sysctl_template="$SYSCTL_TEMPLATE_DIR/99-linux-cli-setup-performance.conf"

    if [[ "$SKIP_PERFORMANCE_TUNING" == "1" ]]; then
        log "Skipping performance tuning because --skip-performance was provided."
        return 0
    fi

    log "Performance tuning: applying common kernel and filesystem settings"
    case "$PACKAGE_FAMILY" in
        debian)
            log "Performance tuning (Debian): using managed sysctl settings and systemd fstrim when available."
            ;;
        arch)
            log "Performance tuning (Arch): using managed sysctl settings and systemd fstrim when available."
            ;;
    esac

    if [[ -f "$sysctl_template" ]]; then
        install_owned_file_optional "$sysctl_template" /etc/sysctl.d/99-linux-cli-setup-performance.conf 0644 root root
        run_step_optional "Applying" "sysctl performance settings" sysctl --system || true
    else
        warn "Missing performance sysctl template: $sysctl_template"
    fi

    if systemd_available && systemctl list-unit-files --no-legend fstrim.timer 2>/dev/null | grep -q '^fstrim\.timer'; then
        run_step_optional "Enabling timer" "fstrim.timer" systemctl enable --now fstrim.timer || true
    else
        log "Performance tuning: fstrim.timer is unavailable; skipping periodic SSD trim enablement."
    fi
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

install_fish_function_templates() {
    local fish_config_dir="$TARGET_HOME/.config/fish"
    local function_name
    local function_template

    [[ "$#" -gt 0 ]] || return 0

    run_step "Creating directory" "$fish_config_dir/functions" install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0755 -d "$fish_config_dir/functions"
    for function_name in "$@"; do
        function_template="$FISH_TEMPLATE_DIR/functions/${function_name}.fish"
        if [[ -f "$function_template" ]]; then
            install_owned_file "$function_template" "$fish_config_dir/functions/${function_name}.fish" 0644 "$TARGET_USER" "$TARGET_GROUP"
        else
            warn "Fish function template not found: $function_template"
        fi
    done
}

configure_fish_files() {
    local fish_config_dir="$TARGET_HOME/.config/fish"

    log "Installing Fish configuration for $TARGET_USER"
    install -o "$TARGET_USER" -g "$TARGET_GROUP" -d "$fish_config_dir" "$fish_config_dir/conf.d"
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
    run_step "Installing" "Fisher and Fish plugins" run_as_target fish -lc "curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; and fisher install jorgebucaran/fisher; and fisher install $plugin_list"

    log "Applying Tide prompt settings"
    run_step "Configuring" "Tide prompt" run_as_target fish "$FISH_TEMPLATE_DIR/configure_tide.fish"
}

update_fisher_plugins() {
    local plugin_list

    if ! command -v fish >/dev/null 2>&1; then
        warn "Fish is not installed; skipping Fisher plugin update"
        return
    fi

    log "Updating Fisher plugins for $TARGET_USER"
    plugin_list="$(grep -Ev '^[[:space:]]*(#|$)' "$FISH_TEMPLATE_DIR/fish_plugins" | tr '\n' ' ')"
    run_step "Updating" "Fisher plugins" run_as_target fish -lc "if functions -q fisher; fisher install $plugin_list; and fisher update; else exit 0; end"
    run_step "Configuring" "Tide prompt" run_as_target fish "$FISH_TEMPLATE_DIR/configure_tide.fish"
}

configure_ssh_client_defaults() {
    local ssh_dir="$TARGET_HOME/.ssh"
    local ssh_config="$ssh_dir/config"
    local include_line='Include ~/.ssh/conf.d/*.conf'
    local config_backup=""
    local config_tmp

    log "Installing SSH client defaults for $TARGET_USER"
    if ! profile_is_selected comfort; then
        debug "Comfort profile is not selected; skipping managed SSH client defaults"
        return
    fi

    if [[ -L "$ssh_dir" || -L "$ssh_dir/conf.d" || -L "$ssh_dir/controlmasters" ]]; then
        warn "Skipping managed SSH defaults because $ssh_dir or one of its managed subdirectories is a symlink."
        return
    fi

    run_step "Creating directory" "$ssh_dir" install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0700 -d "$ssh_dir" "$ssh_dir/conf.d" "$ssh_dir/controlmasters"
    install_owned_file "$SSH_TEMPLATE_DIR/00-defaults.conf" "$ssh_dir/conf.d/00-defaults.conf" 0600 "$TARGET_USER" "$TARGET_GROUP"

    if [[ -L "$ssh_config" ]]; then
        warn "Skipping SSH include update because $ssh_config is a symlink."
        return
    fi

    if [[ -f "$ssh_config" ]] && grep -Fxq "$include_line" "$ssh_config"; then
        run_step "Securing file" "$ssh_config" chmod 0600 "$ssh_config"
        run_step "Setting ownership" "$ssh_config" chown "$TARGET_USER:$TARGET_GROUP" "$ssh_config"
        return
    fi

    config_tmp="$(mktemp)"
    printf '%s\n' "$include_line" > "$config_tmp"

    if [[ -f "$ssh_config" ]]; then
        config_backup="${ssh_config}.linux-cli-setup.${TIMESTAMP}.bak"
        run_step "Backing up" "$ssh_config" cp -p "$ssh_config" "$config_backup"
        record_rollback_cmd "mv -f $(shell_quote "$config_backup") $(shell_quote "$ssh_config")"
        printf '\n' >> "$config_tmp"
        cat "$ssh_config" >> "$config_tmp"
    else
        record_rollback_cmd "rm -f $(shell_quote "$ssh_config")"
    fi

    run_step "Installing file" "$ssh_config" install -o "$TARGET_USER" -g "$TARGET_GROUP" -m 0600 "$config_tmp" "$ssh_config"
    rm -f "$config_tmp"
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

netplan_uses_networkmanager() {
    local file

    compgen -G "/etc/netplan/*.yaml" >/dev/null 2>&1 || return 1
    for file in /etc/netplan/*.yaml; do
        grep -Eiq '^[[:space:]]*renderer:[[:space:]]*NetworkManager[[:space:]]*$' "$file" && return 0
    done

    return 1
}

existing_network_stack_detected() {
    if systemd_available; then
        if systemctl is-active --quiet systemd-networkd.service 2>/dev/null ||
            systemctl is-enabled --quiet systemd-networkd.service 2>/dev/null; then
            return 0
        fi
    fi

    if [[ -f /etc/network/interfaces ]] &&
        grep -Eq '^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+' /etc/network/interfaces; then
        return 0
    fi

    if compgen -G "/etc/netplan/*.yaml" >/dev/null 2>&1 && ! netplan_uses_networkmanager; then
        return 0
    fi

    return 1
}

configure_wireless_networking() {
    if ! profile_is_selected wireless; then
        return
    fi

    if [[ "${LINUX_CLI_ENABLE_NETWORKMANAGER:-auto}" == "0" ]]; then
        log "LINUX_CLI_ENABLE_NETWORKMANAGER=0; skipping NetworkManager service enablement."
        return
    fi

    if ! systemd_available; then
        warn "systemd is unavailable; skipping NetworkManager service enablement."
        return
    fi

    if ! systemctl list-unit-files --no-legend NetworkManager.service 2>/dev/null | grep -q '^NetworkManager\.service'; then
        warn "NetworkManager.service was not found after package installation."
        return
    fi

    if [[ "${LINUX_CLI_ENABLE_NETWORKMANAGER:-auto}" == "1" ]] ||
        systemctl is-active --quiet NetworkManager.service 2>/dev/null ||
        systemctl is-enabled --quiet NetworkManager.service 2>/dev/null ||
        ! existing_network_stack_detected; then
        log "Enabling and starting NetworkManager for the wireless profile"
        run_step_optional "Enabling service" "NetworkManager.service" systemctl enable --now NetworkManager.service || true
        return
    fi

    warn "Existing network configuration was detected; not enabling NetworkManager automatically. Set LINUX_CLI_ENABLE_NETWORKMANAGER=1 to force it."
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
    local docker_required=()

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
    mapfile -t docker_required < <(required_packages_for_profile debian docker)
    install_debian_required_packages "${docker_required[@]}"
}

install_debian_docker_fallback() {
    local reason="${1:-Docker official apt repository is not supported for this release; falling back to distro Docker packages.}"
    local docker_required=()
    local docker_recommended=()

    warn "$reason"
    mapfile -t docker_required < <(distro_required_packages_for_profile debian docker)
    mapfile -t docker_recommended < <(distro_recommended_packages_for_profile debian docker)
    install_debian_required_packages "${docker_required[@]}"
    install_debian_recommended_packages "${docker_recommended[@]}"
}

install_docker_profile() {
    local docker_recommended=()

    case "$PACKAGE_FAMILY" in
        arch)
            install_profile_packages docker
            ;;
        debian)
            if [[ "${LINUX_CLI_DOCKER_APT_SOURCE:-official}" == "distro" ]]; then
                install_debian_docker_fallback "Using distro Docker packages because LINUX_CLI_DOCKER_APT_SOURCE=distro."
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

target_command_exists() {
    local command_name="$1"

    # shellcheck disable=SC2016
    run_as_target bash -lc 'PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"; command -v "$1" >/dev/null 2>&1' bash "$command_name"
}

target_has_cargo() {
    target_command_exists cargo
}

target_has_pipx() {
    target_command_exists pipx
}

install_cargo_tool_if_missing() {
    local command_name="$1"
    local crate_name="$2"

    if target_command_exists "$command_name"; then
        debug "Comfort tool $command_name is already available"
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

install_pipx_tool_if_missing() {
    local command_name="$1"
    local package_name="$2"

    if target_command_exists "$command_name"; then
        debug "Comfort tool $command_name is already available"
        return 0
    fi

    if ! target_has_pipx; then
        warn "pipx is unavailable; skipping fallback install for $command_name"
        return 0
    fi

    run_step_optional "Configuring" "pipx user path" run_as_target pipx ensurepath
    if run_step_optional "${PACKAGE_STEP_VERB:-Installing}" "pipx tool $package_name" run_as_target pipx install "$package_name"; then
        record_rollback_cmd "runuser -u $(shell_quote "$TARGET_USER") -- env HOME=$(shell_quote "$TARGET_HOME") PATH=$(shell_quote "$TARGET_HOME/.local/bin:/usr/local/bin:/usr/bin:/bin") pipx uninstall $(shell_quote "$package_name")"
    fi
}

install_comfort_fallback_tools() {
    local tool_pair
    local command_name
    local package_name
    local -a cargo_tools=(
        "atuin:atuin"
        "zoxide:zoxide"
        "mise:mise"
        "just:just"
        "watchexec:watchexec-cli"
        "hyperfine:hyperfine"
        "tldr:tealdeer"
        "jless:jless"
        "delta:git-delta"
        "difft:difftastic"
        "rga:ripgrep_all"
        "yazi:yazi-fm"
        "zellij:zellij"
    )
    local -a pipx_tools=(
        "http:httpie"
        "trash-put:trash-cli"
    )

    log "Checking comfort tool fallbacks for $TARGET_USER"
    for tool_pair in "${cargo_tools[@]}"; do
        command_name="${tool_pair%%:*}"
        package_name="${tool_pair#*:}"
        install_cargo_tool_if_missing "$command_name" "$package_name"
    done

    for tool_pair in "${pipx_tools[@]}"; do
        command_name="${tool_pair%%:*}"
        package_name="${tool_pair#*:}"
        install_pipx_tool_if_missing "$command_name" "$package_name"
    done
}

install_comfort_tools() {
    install_comfort_fallback_tools
}

install_status_commands() {
    install_owned_file "$BIN_TEMPLATE_DIR/time-status" /usr/local/bin/time-status 0755 root root
    install_owned_file "$BIN_TEMPLATE_DIR/ntp-status" /usr/local/bin/ntp-status 0755 root root
}

chrony_service_name() {
    case "$PACKAGE_FAMILY" in
        debian)
            printf 'chrony.service'
            ;;
        arch)
            printf 'chronyd.service'
            ;;
        *)
            printf 'chronyd.service'
            ;;
    esac
}

chrony_config_path() {
    case "$PACKAGE_FAMILY" in
        debian)
            printf '/etc/chrony/chrony.conf'
            ;;
        arch)
            printf '/etc/chrony.conf'
            ;;
        *)
            printf '/etc/chrony.conf'
            ;;
    esac
}

disable_legacy_time_sync_service() {
    if systemd_available && systemctl list-unit-files --no-legend systemd-timesyncd.service 2>/dev/null | grep -q '^systemd-timesyncd\.service'; then
        run_step_optional "Disabling service" "systemd-timesyncd.service" systemctl disable --now systemd-timesyncd.service || true
    fi

    run_step_optional "Removing file" "/etc/systemd/timesyncd.conf.d/10-linux-cli-setup.conf" rm -f /etc/systemd/timesyncd.conf.d/10-linux-cli-setup.conf || true

    if [[ "$PACKAGE_FAMILY" == "debian" ]] && package_is_installed systemd-timesyncd; then
        record_rollback_cmd "DEBIAN_FRONTEND=noninteractive apt-get install -y systemd-timesyncd"
        export DEBIAN_FRONTEND=noninteractive
        run_step_optional "Removing" "apt package systemd-timesyncd" apt-get remove -y systemd-timesyncd || true
    fi
}

configure_time_sync() {
    local old_timezone=""
    local chrony_service
    local chrony_config

    old_timezone="$(timedatectl show -p Timezone --value 2>/dev/null || true)"

    if [[ -n "$old_timezone" ]]; then
        record_rollback_cmd "timedatectl set-timezone $(shell_quote "$old_timezone")"
    fi

    if command -v timedatectl >/dev/null 2>&1; then
        run_step "Configuring timezone" "America/Detroit" timedatectl set-timezone America/Detroit
    else
        [[ -f /etc/localtime ]] && backup_existing_path /etc/localtime
        [[ -f /etc/timezone ]] && backup_existing_path /etc/timezone
        run_step "Configuring timezone" "/etc/localtime" ln -snf /usr/share/zoneinfo/America/Detroit /etc/localtime
        printf '%s\n' "America/Detroit" > /etc/timezone
    fi

    log "Configuring chrony for DHCP-provided NTP servers with us.pool.ntp.org fallback"
    disable_legacy_time_sync_service
    chrony_service="$(chrony_service_name)"
    chrony_config="$(chrony_config_path)"

    run_step "Creating directory" "/etc/chrony/sources.d" install -m 0755 -d /etc/chrony/sources.d
    run_step "Creating directory" "/run/chrony-dhcp" install -m 0755 -d /run/chrony-dhcp
    install_owned_file "$CHRONY_TEMPLATE_DIR/chrony.conf" "$chrony_config" 0644 root root
    install_owned_file "$CHRONY_TEMPLATE_DIR/tmpfiles.conf" /etc/tmpfiles.d/linux-cli-chrony.conf 0644 root root
    install_owned_file "$CHRONY_TEMPLATE_DIR/chrony-dhcp-source" /usr/local/sbin/linux-cli-chrony-dhcp-source 0755 root root
    install_owned_file "$CHRONY_TEMPLATE_DIR/networkmanager-dispatcher" /etc/NetworkManager/dispatcher.d/20-linux-cli-chrony-dhcp 0755 root root
    install_owned_file "$CHRONY_TEMPLATE_DIR/dhclient-exit-hook" /etc/dhcp/dhclient-exit-hooks.d/linux-cli-chrony 0644 root root

    if command -v systemd-tmpfiles >/dev/null 2>&1; then
        run_step_optional "Creating runtime directory" "/run/chrony-dhcp" systemd-tmpfiles --create /etc/tmpfiles.d/linux-cli-chrony.conf || true
    fi

    if systemd_available; then
        run_step "Enabling service" "$chrony_service" systemctl enable --now "$chrony_service"
        run_step_optional "Restarting service" "$chrony_service" systemctl restart "$chrony_service" || true
    else
        warn "systemd is unavailable; chrony was configured but not enabled by this script."
    fi
}

configure_fail2ban() {
    log "Configuring fail2ban for SSH protection"
    install_owned_file "$FAIL2BAN_TEMPLATE_DIR/jail.d/linux-cli-setup.conf" /etc/fail2ban/jail.d/linux-cli-setup.conf 0644 root root

    if systemd_available; then
        run_step "Enabling service" "fail2ban.service" systemctl enable --now fail2ban.service
        run_step_optional "Restarting service" "fail2ban.service" systemctl restart fail2ban.service || true
    else
        warn "systemd is unavailable; fail2ban was configured but not enabled by this script."
    fi
}

configure_logrotate() {
    log "Configuring logrotate for linux-cli-setup logs"
    install_owned_file "$LOGROTATE_TEMPLATE_DIR/linux-cli-setup" /etc/logrotate.d/linux-cli-setup 0644 root root
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

profiles_csv_to_lines() {
    local raw="$1"
    local profile
    local -a parsed_profiles

    IFS=',' read -r -a parsed_profiles <<< "$raw"
    for profile in "${parsed_profiles[@]}"; do
        profile="$(trim_string "$profile")"
        [[ -n "$profile" ]] || continue
        is_supported_profile "$profile" || continue
        printf '%s\n' "$profile"
    done
}

package_belongs_to_profiles() {
    local package="$1"
    local family="$2"
    shift 2
    local profile
    local profile_package

    for profile in "$@"; do
        while IFS= read -r profile_package; do
            [[ "$package" == "$profile_package" ]] && return 0
        done < <(all_packages_for_profile "$family" "$profile")
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
    shift
    local retained_profiles=("$@")
    local packages=()
    local package

    mapfile -t packages < <(all_packages_for_profile "$PACKAGE_FAMILY" "$profile")

    [[ "${#packages[@]}" -gt 0 ]] || return 0

    case "$PACKAGE_FAMILY" in
        debian)
            export DEBIAN_FRONTEND=noninteractive
            for package in "${packages[@]}"; do
                if package_belongs_to_profiles "$package" "$PACKAGE_FAMILY" "${retained_profiles[@]}"; then
                    log "Skipping retained apt package $package"
                    continue
                fi
                if package_is_installed "$package"; then
                    run_step_optional "Uninstalling" "apt package $package" apt-get remove -y "$package"
                else
                    log "Skipping absent apt package $package"
                fi
            done
            ;;
        arch)
            for package in "${packages[@]}"; do
                if package_belongs_to_profiles "$package" "$PACKAGE_FAMILY" "${retained_profiles[@]}"; then
                    log "Skipping retained pacman package $package"
                    continue
                fi
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
