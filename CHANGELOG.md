# Changelog

All notable changes to this project will be documented in this file.

## 0.3a - Unreleased

### Added

- Added the optional `comfort` profile for shell workflow tools, safer Fish abbreviations, managed Fish helper functions, and managed SSH client defaults.
- Added best-effort cargo and pipx fallback installs for selected `comfort` tools when distro packages are unavailable.
- Added `ufw` to the required `core` package group with managed default-deny firewall configuration for SSH, iperf3, and ping.
- Added `rkhunter` to the `netops` package group.
- Added the optional `wireless` profile for NetworkManager, Wi-Fi tooling, firmware packages, RF-kill controls, mobile broadband support, and wireless Fish helpers.
- Added `install_test.sh` to check package availability across selected profiles without installing anything.
- Added a managed basic sysctl hardening template.

### Changed

- Changed Fish plugin setup to use `zoxide` for directory jumping and added `edc/bass` to the managed Fisher plugin list.
- Changed install and update to apply best-effort basic hardening, configure UFW, and clean unused packages plus package caches near the end of each run.

## 0.2a - 2026-06-30

### Added

- Added `data/package-groups.tsv` as the editable source for package group mappings across Arch and Debian/Ubuntu.
- Added an interactive install prompt for optional `dev`, `netops`, `docker`, and `desktop` groups when no explicit group option is provided.
- Added a GitHub release/prerelease self-update check for install, update, and uninstall scripts before they make system changes.
- Added `vim` to the required `core` package group for Arch and Debian/Ubuntu systems.
- Added NFS client packages to the required `core` package group: `nfs-utils` on Arch and `nfs-common` on Debian/Ubuntu.

### Changed

- Changed install and update ordering so `core` always runs first and saved state keeps `core` first.
- Changed update behavior to read saved install groups and install missing packages from the current package group map.
- Changed package uninstall behavior so `--remove-packages` defaults to saved optional groups, always leaves `core` packages installed, and skips packages that belong to retained saved groups.
- Changed root entrypoint wrappers to preserve the original script path so self-updates can restart the same command after pulling the newer release.

## 0.1a - 2026-06-30

Alpha prerelease for initial private testing.

### Added

- Added the initial Linux CLI setup installer with Arch/pacman and Debian/Ubuntu/apt detection.
- Added automatic package updates, OpenSSH enablement, common CLI package installation, Fish default-shell setup, Fisher/Tide plugin setup, JetBrainsMono Nerd Font Mono installation, and dynamic MOTD installation.
- Added Fish, Tide, and MOTD templates plus required project documentation.
- Added profile-based installs for `core`, `dev`, `netops`, `diagnostics`, `docker`, and `desktop` instead of one large install set.
- Added shared install/update/uninstall logic with saved install state under `/var/lib/linux-cli-setup`.
- Added `update.sh` to refresh system packages, selected profiles, managed Fish config, Fisher plugins, Tide settings, and MOTD.
- Added `uninstall.sh` to remove managed Fish/MOTD files, restore the saved default shell, and optionally remove profile packages.
- Added Git default configuration, Arch/Debian distro helpers, Docker profile behavior, pipx developer tools, and Fish abbreviations for common CLI and Docker commands.
- Added colored per-item script output, per-run log files, `--debug` output, command-output snippets on failure, and rollback handling for install/update managed changes.
- Added `time-status` and `ntp-status` commands plus timezone and NTP setup for `America/Detroit` with `us.pool.ntp.org` fallback.
- Added a Debian/Ubuntu and Arch automatic update script with root-only Pushover config, systemd timer scheduling between 3:30 AM and 4:30 AM, and cron fallback.
- Added `VERSION` as the version source and `--version` support for executable scripts.
- Added an ignored root `.auto-update.conf` local testing config while keeping the committed runtime template secret-free.

### Changed

- Expanded `README.md` and `AGENTS.md` with the attached profile recommendations, package mappings, Docker guidance, update flow, uninstall flow, and validation contract.
- Updated uninstall behavior to keep running after individual errors while reporting failed items.
