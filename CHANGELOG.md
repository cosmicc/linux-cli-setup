# Changelog

All notable changes to this project will be documented in this file.

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
