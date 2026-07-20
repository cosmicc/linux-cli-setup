#!/usr/bin/env bash
# Verify Fastfetch MOTD selection, Garuda defaults, package enforcement, and the
# managed Fish block lifecycle without changing the development host.
# shellcheck disable=SC2329 # Test seams are invoked indirectly by sourced functions.

set -Eeuo pipefail

TEST_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEST_PROJECT_ROOT="$(cd -- "$TEST_SCRIPT_DIR/.." && pwd)"
TEST_ROOT="$(mktemp -d /tmp/linux-cli-setup-fastfetch-test.XXXXXX)"

cleanup() {
    case "$TEST_ROOT" in
        /tmp/linux-cli-setup-fastfetch-test.*)
            find "$TEST_ROOT" -depth -delete
            ;;
        *)
            printf 'Refusing to clean unexpected test path: %s\n' "$TEST_ROOT" >&2
            return 1
            ;;
    esac
}
trap cleanup EXIT

# shellcheck disable=SC1091
source "$TEST_PROJECT_ROOT/scripts/lib/linux-cli-common.sh"
# shellcheck disable=SC1091
source "$TEST_PROJECT_ROOT/scripts/lib/package-install-overrides.sh"

# Test explicit Fastfetch selection without depending on the development host.
is_garuda_linux() {
    return 1
}
fastfetch_motd_available() {
    return 0
}

TARGET_HOME="$TEST_ROOT/home"
TARGET_USER="$(id -un)"
TARGET_GROUP="$(id -gn)"
export TARGET_HOME TARGET_USER TARGET_GROUP
fish_config="$TARGET_HOME/.config/fish/config.fish"
install -d "$TARGET_HOME/.config/fish"
cp "$FISH_TEMPLATE_DIR/config.fish" "$fish_config"

MOTD_MODE=fastfetch
MOTD_MODE_EXPLICIT=1
LINUX_CLI_MOTD_MODE=""
export MOTD_MODE MOTD_MODE_EXPLICIT LINUX_CLI_MOTD_MODE
resolve_motd_mode
[[ "$MOTD_MODE" == "fastfetch" ]]

install_fastfetch_fish_motd_block
install_fastfetch_fish_motd_block
[[ "$(grep -Fxc "$FASTFETCH_FISH_MOTD_BEGIN" "$fish_config")" -eq 1 ]]
[[ "$(grep -Fxc "$FASTFETCH_FISH_MOTD_END" "$fish_config")" -eq 1 ]]
grep -Fq 'fastfetch --config neofetch.jsonc' "$fish_config"

remove_fastfetch_fish_motd_block "$fish_config"
cmp -s "$fish_config" "$FISH_TEMPLATE_DIR/config.fish"

printf '%s\n' 'fastfetch --config neofetch.jsonc' >> "$fish_config"
install_fastfetch_fish_motd_block
[[ "$(grep -Fc 'fastfetch --config neofetch.jsonc' "$fish_config")" -eq 1 ]]
if grep -Fq "$FASTFETCH_FISH_MOTD_BEGIN" "$fish_config"; then
    printf 'Managed block duplicated existing Fastfetch startup information.\n' >&2
    exit 1
fi

cp "$FISH_TEMPLATE_DIR/config.fish" "$fish_config"
printf '%s\n' '# Unrelated user Fish setting.' >> "$fish_config"
install_fastfetch_fish_motd_block
MOTD_MODE=replace
sync_fastfetch_fish_motd_block
grep -Fq '# Unrelated user Fish setting.' "$fish_config"
if grep -Fq "$FASTFETCH_FISH_MOTD_BEGIN" "$fish_config"; then
    printf 'Managed Fastfetch MOTD marker remained after removal.\n' >&2
    exit 1
fi

fastfetch_install_called=0
install_fastfetch_motd() {
    fastfetch_install_called=1
}
MOTD_MODE=fastfetch
install_motd
[[ "$fastfetch_install_called" -eq 1 ]]

# Systems without an installed or packaged Fastfetch command do not show it in
# the interactive choice list.
fastfetch_motd_available() {
    return 1
}
is_garuda_linux() {
    return 1
}
MOTD_MODE=""
prompt_for_motd_mode > "$TEST_ROOT/unavailable-prompt.txt" <<< ""
[[ "$MOTD_MODE" == "replace" ]]
if grep -Fq '4) fastfetch' "$TEST_ROOT/unavailable-prompt.txt"; then
    printf 'Unavailable Fastfetch mode appeared in the interactive prompt.\n' >&2
    exit 1
fi

# Garuda defaults to Fastfetch only when no explicit or saved choice exists.
is_garuda_linux() {
    return 0
}
fastfetch_motd_available() {
    return 0
}
read_state_value() {
    return 1
}
MOTD_MODE=""
MOTD_MODE_EXPLICIT=0
resolve_motd_mode
[[ "$MOTD_MODE" == "fastfetch" ]]

MOTD_MODE=keep
MOTD_MODE_EXPLICIT=1
resolve_motd_mode
[[ "$MOTD_MODE" == "keep" ]]

read_state_value() {
    [[ "$1" == "motd_mode" ]] && printf 'combine\n'
}
MOTD_MODE=""
MOTD_MODE_EXPLICIT=0
resolve_motd_mode
[[ "$MOTD_MODE" == "combine" ]]

# Explicit Fastfetch selection is rejected when neither command nor package is
# available, and becomes a required verified install when it is available.
if (
    fastfetch_motd_available() { return 1; }
    MOTD_MODE=fastfetch
    MOTD_MODE_EXPLICIT=1
    resolve_motd_mode
) >/dev/null 2>&1; then
    printf 'Unavailable Fastfetch mode was accepted.\n' >&2
    exit 1
fi

fastfetch_installed=0
target_command_exists() {
    [[ "$fastfetch_installed" -eq 1 ]]
}
package_is_available() {
    [[ "$1" == "fastfetch" ]]
}
install_debian_required_packages() {
    [[ "$1" == "fastfetch" ]]
    fastfetch_installed=1
}
PACKAGE_FAMILY=debian
export PACKAGE_FAMILY
MOTD_MODE=fastfetch
ensure_fastfetch_motd_command
[[ "$fastfetch_installed" -eq 1 ]]

printf 'Fastfetch MOTD behavior checks passed.\n'
