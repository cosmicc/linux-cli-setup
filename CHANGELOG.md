# Changelog

All notable changes to this project will be documented in this file.

## 0.4a - Unreleased

### Added

- Added chrony, fail2ban, and logrotate to the core package set for baseline NTP, SSH protection, and log maintenance.
- Added managed chrony configuration with DHCP NTP sources and `us.pool.ntp.org` fallback.
- Added managed NetworkManager and dhclient hooks that pass DHCP-provided NTP servers to chrony.
- Added a managed systemd-tmpfiles entry for chrony's DHCP source directory.
- Added a managed fail2ban SSH jail that reads from the systemd journal and bans through UFW.
- Added a managed logrotate policy for `/var/log/linux-cli-setup/*.log`.
- Added default performance tuning with a managed sysctl profile and `fstrim.timer` enablement when available.
- Added an explicit default hardening section with managed sysctl protections, OpenSSH daemon guardrails, and Debian apt repository safety settings.
- Added `--skip-performance` and `--skip-hardening` options for hosts that need to avoid those managed changes.
- Added a `timecheck` utility with an `ntpcheck` alias for chrony/NTP status, selected time source, and stratum details.
- Added transaction signal handling so interrupted install, refresh, and uninstall runs roll back before exiting.
- Added a transaction exit backstop so unexpected nonzero install, refresh, and uninstall exits roll back active changes while skipping over rollback-command failures.

### Changed

- Changed package action output to show the owning profile as `profile/package` and switched action lines away from dark blue to a brighter console color.
- Changed time synchronization from systemd-timesyncd to chrony and disabled the previous timesyncd service during install or refresh.
- Changed the package group source from tab-delimited `data/package-groups.tsv` to editable `data/package-groups.yaml`.
- Changed the installed auto-update command to `/usr/local/bin/auto-update` and the runtime config to `/etc/auto-update.conf`, with cleanup for the previous managed paths.
- Changed the Docker status utility name from `docker-status` to `dockercheck`.
- Enabled cargo source-build fallbacks by default for missing comfort tools; set `LINUX_CLI_ENABLE_CARGO_FALLBACKS=0` to opt out.
- Changed cargo fallback installs to pin compatible `mise` and `watchexec-cli` versions when the target Rust compiler is older than newer crate releases require.
- Added Debian/Ubuntu comfort source-build prerequisites so cargo fallbacks can compile crates that need OpenSSL headers.
- Removed OpenVPN, WireGuard, SNMP tooling, and duplicate `rsync` entries from the netops profile; `rsync` remains in core.
- Moved fail2ban ownership from the netops profile into core.
- Changed the Arch archive package mapping from retired `p7zip` to current `7zip`.
- Changed package mappings so Arch rows use pacman packages and Debian rows use Debian stable package names, except Docker's official apt repository package path.
- Restored automatic yay bootstrap and AUR fallback installs for optional Arch packages so the Arch install can be more complete.
- Restored Arch `aide` and `hadolint` as yay/AUR-backed optional package entries.
- Clarified `update.sh --help` now that updates are handled through the installer refresh path.
- Corrected the agent validation commands so Bash and Fish syntax checks cover every listed file.

### Fixed

- Fixed `install_test.sh` logging fallback when `/var/log/linux-cli-setup` exists but is not writable by the current user.
- Fixed non-interactive Tide prompt configuration returning exit code `1` when Tide OS detection is unavailable even though the fallback OS icon was written.

## 0.3a - 07.05.2026

### Added

- Added the optional `comfort` profile for shell workflow tools, safer Fish abbreviations, managed Fish helper functions, and managed SSH client defaults.
- Added best-effort cargo and pipx fallback installs for selected `comfort` tools when distro packages are unavailable.
- Added `ufw` to the required `core` package group with managed default-deny firewall configuration for SSH, iperf3, and ping.
- Added `rkhunter` to the `netops` package group.
- Added the optional `wireless` profile for NetworkManager, Wi-Fi tooling, firmware packages, RF-kill controls, mobile broadband support, and wireless Fish helpers.
- Added `install_test.sh` to check package availability across selected profiles without installing anything.
- Added a managed basic sysctl hardening template.
- Added installation and managed uninstall cleanup for utility commands from `scripts/utilities/`.
- Added `lynis`, `aide`, `rsync`, `pv`, `glances`, `atop`, `dool`/`dstat`, `vnstat`, and `bmon` to the `core` package set.
- Added the optional `storage` profile for filesystem, removable-media, SMB/CIFS, encryption, recovery, and flash-media validation tools.
- Added `sslscan`, `testssl.sh`, `fping`, and Debian/Ubuntu `ncat` coverage to the `netops` package set.
- Added managed Fish abbreviations for common navigation, systemd, journal, IP/DNS, Docker, and Git commands plus an `aliases` utility that prints Fish abbreviations and aliases.

### Changed

- Changed Fish plugin setup to use `zoxide` for directory jumping and added `edc/bass` to the managed Fisher plugin list.
- Changed Fish prompt management to use the reference Tide-generated `fish_prompt` loader and a complete managed Tide variable set, with install/refresh runs updating both after Tide configuration.
- Changed `install.sh` so a fresh no-profile run installs core only, while a no-profile run on an existing linux-cli-setup install refreshes the saved profiles.
- Changed `update.sh` into a compatibility wrapper for `install.sh` and removed the separate update implementation.
- Changed `uninstall.sh --remove-packages` so saved-profile removal includes `core` by default, and added safe cleanup for the automatic update config.
- Changed install and saved-profile refresh to apply best-effort basic hardening, configure UFW, and clean unused packages plus package caches near the end of each run.

### Fixed

- Fixed the managed Tide prompt to enable the reference Git, job, environment, language/toolchain, cloud, Kubernetes, container, and time items instead of only path, command duration, context, and time.
- Fixed the managed Tide Git prompt item to use the reference Nerd Font git icon instead of the text `git` label.
- Fixed install, update, uninstall, and package availability tests to fail clearly on systems without `pacman` or `apt-get`, before self-update or managed-file changes.
- Fixed the managed Tide prompt shape so the left OS/path block and right context/time block use rounded segment caps, dark backgrounds, and visible internal dividers.
- Fixed the managed Tide right prompt so the command-duration segment appears before context/time after long-running commands.
- Fixed managed Tide prompt colors to use Fish-compatible hex values instead of raw 256-color indexes.
- Fixed managed Tide OS segment color detection so the generated prompt receives icon, foreground, and background values.

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
