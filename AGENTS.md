# AGENTS.md

This is the first-read guide for agents working in `linux-cli-setup`. Read this file before changing code, templates, package lists, or documentation.

## Project Purpose

This project provides root-run Linux setup, refresh, and uninstall scripts for CLI-focused systems. It supports Arch-based systems with `pacman`/`yay` and Debian/Ubuntu-based systems with `apt`. The default fresh install is the `core` profile; optional profiles add CLI comfort tools, development, network troubleshooting, wireless support, storage/filesystem tooling, diagnostics, Docker host, and desktop workstation tooling.

## Repository Map

- `install.sh`, `update.sh`, and `uninstall.sh` are root entry points. Keep them small wrappers. `update.sh` is only a compatibility wrapper to `install.sh`.
- `install_test.sh` is the non-mutating package availability diagnostic entry point.
- `VERSION` is the project version source. Update it with every release or prerelease.
- `data/package-groups.tsv` is the editable package group map. Scripts read package names from this file at runtime.
- `scripts/setup-linux-cli.sh` contains the install and saved-profile refresh flow.
- `scripts/uninstall-linux-cli.sh` contains the uninstall flow.
- `scripts/install-test-linux-cli.sh` contains the package availability diagnostic flow.
- `scripts/lib/linux-cli-common.sh` contains shared profile, package, distro, user, Fish, Git, MOTD, Docker, and safety helpers.
- `scripts/lib/package-install-overrides.sh` contains runtime install overrides for availability-aware package installs and installed utility commands.
- `scripts/utilities/` contains managed utility commands copied to `/usr/local/bin`, including `aliases` for printing Fish abbreviations and aliases.
- `templates/fish/` contains Fish, Fisher, Tide, abbreviation, and fallback MOTD hook templates.
- `templates/sysctl/` contains managed sysctl hardening templates.
- `templates/motd/linux-cli-motd` contains the dynamic MOTD script installed on target systems.
- `templates/bin/` contains installed CLI status commands such as `time-status` and `ntp-status`.
- `templates/auto-update/` contains the installed automatic update script and root-only config template.
- `templates/systemd/` and `templates/cron/` contain automatic update scheduling templates.
- `README.md` is the user-facing overview and usage guide.
- `CHANGELOG.md` records notable changes for each version and unreleased change set.

## Profile Contract

Do not collapse this project into one giant "install everything" profile. Keep `core` as the always-installed baseline and keep heavier tools behind profiles:

| Profile | Role |
| --- | --- |
| `core` | Always-installed CLI baseline, Fish prompt, Git defaults, MOTD, and distro helpers. |
| `comfort` | CLI workflow helpers, safer shell shortcuts, Fish functions, and SSH client defaults. |
| `dev` | Python, C/C++ build tools, Neovim, uv, pipx tools, and developer Git helpers. |
| `netops` | DNS, packet capture, port scanning, VPN, SSH, transfer, and MSP troubleshooting tools. |
| `wireless` | NetworkManager, Wi-Fi scanning, firmware, RF-kill, mobile broadband, and wireless CLI helpers. |
| `storage` | Filesystem, removable media, SMB/CIFS, encryption, recovery, and flash-media tools. |
| `diagnostics` | Hardware, disk, sensor, I/O, network usage, tracing, and process diagnostics. |
| `docker` | Docker host packages, Compose plugin, Docker CLI helpers, and Fish Docker aliases. |
| `desktop` | GUI workstation clipboard, desktop integration, and notification helpers. |

`install.sh` always includes `core`; optional profiles are selected with `--profile`, `--profiles`, or `--all-profiles`. `update.sh` is retained only for compatibility and delegates to `install.sh`.

When `install.sh` is run without an explicit profile option and no install state exists, install `core` only. Do not prompt for optional profiles. Keep `diagnostics` available for backward-compatible explicit use with `--profile diagnostics`.

Keep `core` first in install, refresh execution order, and saved state. When `install.sh` is run without an explicit profile option and install state exists, use the profiles saved by install, read the current package group map, install missing packages for those saved profiles, and log that everything was installed already and `install.sh` is running an update. `uninstall.sh --remove-packages` should default to saved profiles, including `core`, and avoid removing packages that belong to retained profiles only when the user explicitly selects a subset.

## Installer Contract

- The installer must be run as root, normally through `sudo ./install.sh`.
- The target account is the sudoing user from `$SUDO_USER`, not `root`. Root-only direct runs must require `TARGET_USER=username` or saved state.
- Package-family detection should stay conservative: prefer `pacman` for Arch-based systems and `apt-get` for Debian/Ubuntu-based systems.
- Install, update, uninstall, and package availability tests must fail clearly on systems without `pacman` or `apt-get`. Install/update/uninstall should run this support check after root/log initialization and before GitHub self-update or managed-file changes.
- Arch installs must ensure `yay` is available before AUR fallback installs.
- Debian/Ubuntu scripts must use noninteractive `apt-get`. Installing `nala` is fine, but scripts must not depend on it.
- Existing user Fish files must be backed up before replacement unless the installed file already matches the project template.
- Fish should become the target user's default shell through `/etc/shells` plus `chsh` or `usermod`.
- Install state belongs in `/var/lib/linux-cli-setup/install.env`; preserve the originally saved shell across updates.
- Package group contents belong in `data/package-groups.tsv`, not hardcoded shell case blocks. The file uses tab-separated columns for group, tier, Arch packages, Debian/Ubuntu packages, and notes.
- Script logs belong in `/var/log/linux-cli-setup/`; create one log file per install, update, uninstall, or auto-update execution.
- `install_test.sh` may run without root and may fall back to a repository-local `logs/` directory when `/var/log/linux-cli-setup/` is not writable. It must not install, update, remove, enable, or disable anything. On Arch, it may use the read-only AUR RPC to verify documented AUR fallback packages when `yay` is not installed.
- Package-manager output must stay suppressed by default. Console output should show each item being installed, updated, or uninstalled, with colored status lines unless `--no-color` is passed.
- Executable script options must use long `--option` names only. Keep `--help` and `--version` on executable scripts.
- After root detection and log initialization, install and uninstall must check GitHub releases and prereleases for a newer project version before making system changes. The compatibility `update.sh` wrapper delegates to `install.sh`, so it receives the same check there. If a newer version is available, fetch and pull from the trusted `cosmicc/linux-cli-setup` `origin/main`, show Git progress, create a temporary restart wrapper under `/tmp`, and exec the same entrypoint with the original arguments. Keep `LINUX_CLI_SELF_UPDATE_RESTARTED=1` as the loop guard.
- Self-update version ordering must support alpha and beta prerelease labels such as `0.1a` and `0.5b`, with final releases such as `v1.0` ranking after prereleases at the same numeric version. Do not auto-update from an unexpected GitHub remote.
- `--debug` must show captured command output and command details in both console and log files.
- Required install/update failures must print the error and the last captured output for the failing item, then roll back managed changes from that run. Package-manager system upgrades are not fully reversible; document that limit instead of pretending otherwise.
- Install and saved-profile refresh should configure UFW after OpenSSH is enabled. Preserve existing UFW rules, set default deny incoming/default allow outgoing, allow SSH, allow iperf3 on TCP/UDP `5201`, and keep ICMP echo-request ping allowed.
- Install and saved-profile refresh should apply only basic, non-obtrusive OS hardening. Hardening must be best-effort and must not abort the installer.
- Install and saved-profile refresh should remove unused packages and clean package caches near the end of the run. Cleanup failures should warn and continue.
- Uninstall must keep going after individual errors and report warnings instead of aborting the whole run.
- Full package removal must remain behind the explicit `--remove-packages` flag. Exact restoration of package-manager upgrades, firewall state, time settings, service enablement, and packages that predated linux-cli-setup is not guaranteed unless the project has tracked that specific prior state.
- Do not hardcode secrets, private URLs, credentials, tokens, or environment-specific host names.

## Package Recommendations

Keep these package mappings aligned with `data/package-groups.tsv`. The TSV file is authoritative for script behavior; these tables are explanatory documentation.

### Core

Core always includes OpenSSH, Git, Vim, NFS client support, UFW firewall, chrony, fail2ban, logrotate, Fish, htop, btop, JetBrainsMono Nerd Font Mono, Fisher, Tide, prompt config, and MOTD.

| Purpose | Arch / Garuda | Debian / Ubuntu |
| --- | --- | --- |
| Downloads / repos | `curl`, `wget`, `ca-certificates`, `gnupg` | `curl`, `wget`, `ca-certificates`, `gnupg` |
| Archives | `unzip`, `zip`, `7zip`, `tar`, `gzip`, `xz` | `unzip`, `zip`, `p7zip-full`, `tar`, `gzip`, `xz-utils` |
| Terminal multiplexer | `tmux` | `tmux` |
| Baseline editor | `vim` | `vim` |
| NFS client support | `nfs-utils` | `nfs-common` |
| Firewall | `ufw` | `ufw` |
| Search / navigation | `ripgrep`, `fd`, `fzf`, `plocate` | `ripgrep`, `fd-find`, `fzf`, `plocate` |
| File viewing | `bat`, `eza`, `tree`, `less` | `bat`, `eza`, `tree`, `less` |
| JSON / YAML | `jq`, `yq` | `jq`, `yq` |
| Disk usage | `ncdu`, `duf`, `dust` | `ncdu`, `duf` |
| Logs | `lnav` | `lnav` |
| Docs / help | `man-db`, `man-pages`, `tldr` | `man-db`, `manpages`, `tldr` |
| System info | `fastfetch`, `inxi` | `fastfetch`, `inxi` |
| Dotfiles | `chezmoi` | `chezmoi` |
| Time sync / SSH protection / log rotation | `chrony`, `fail2ban`, `logrotate` | `chrony`, `fail2ban`, `logrotate` |
| Security audit / integrity | `lynis`, `aide` | `lynis`, `aide` |
| Transfer / throughput | `rsync`, `pv` | `rsync`, `pv` |
| System and network monitors | `glances`, `atop`, `dool`, `vnstat`, `bmon` | `glances`, `atop`, `dstat`, `vnstat`, `bmon` |
| Nerd Font package | `ttf-jetbrains-mono-nerd` | installed from Nerd Fonts release fallback |

Arch-specific core additions are `pacman-contrib`, `reflector`, `pkgfile`, and `base-devel`. Enable `paccache.timer` and run `pkgfile -u` when available.

Debian/Ubuntu-specific additions are `apt-file`, `needrestart`, `debian-goodies`, `software-properties-common`, `apt-transport-https`, `unattended-upgrades`, and `nala`.

Arch does not ship `aide` in the official repositories; keep it recommended so the existing `yay` fallback can install the AUR `aide` package without making core a hard failure. Debian/Ubuntu does not ship `dool` in the stable package set, so the apt-side package is `dstat`.

### Comfort

The `comfort` profile is the optional CLI workflow layer. It should prefer distro packages from `data/package-groups.tsv`, then attempt user-level cargo or pipx fallback installs only for missing tools where a known package/crate mapping exists. Keep fallback installs best-effort and non-system-wide.

Comfort includes Fish integrations for `atuin`, `zoxide`, `direnv`, and `mise` when those commands exist. Keep Tide as the prompt because the project intentionally uses Fish + Tide to match the screenshot. Do not switch to Starship unless the user explicitly asks.

Managed Fish functions live under `templates/fish/functions/` and are installed into the target user's `~/.config/fish/functions/`. The managed `fish_prompt.fish` must use Tide's generated prompt-loader pattern from the reference system, including the per-session `_tide_prompt_$fish_pid` variable, so the prompt is rebuilt from Tide items instead of a stale hardcoded cache variable. The Tide variables in `templates/fish/configure_tide.fish` must produce the reference two-line prompt with OS/current directory and Git status on the left, rounded prompt segment caps, a horizontal frame, a rounded right prompt with command-duration, context, jobs, environment, language/toolchain, cloud, Kubernetes, container, and time items, and the prompt character on the second line. The Git prompt item must use the Nerd Font git icon, not a text `git` label. Tool-specific Tide items should stay hidden until their supporting command and project marker or environment are present. The command-duration segment should appear only after commands longer than the configured Tide threshold. Install and saved-profile refresh must refresh Tide settings and the managed prompt file so rerunning `install.sh` restores the managed prompt. The default managed Fisher plugin list is `jorgebucaran/fisher`, `IlanCosman/tide@v6`, `patrickf1/fzf.fish`, `jorgebucaran/autopair.fish`, `edc/bass`, and `franciscolourenco/done`; keep these enabled by default unless the user asks to remove one. Managed SSH client defaults live under `templates/ssh/`; install them through an include file under `~/.ssh/conf.d/` and do not overwrite the user's full `~/.ssh/config`.

### Git Defaults

Apply these Git defaults for the target user:

```bash
git config --global init.defaultBranch main
git config --global pull.ff only
git config --global fetch.prune true
git config --global merge.conflictstyle zdiff3
git config --global rerere.enabled true
git config --global core.editor nvim
```

If `delta` exists, configure `core.pager`, `interactive.diffFilter`, `delta.navigate`, and `delta.side-by-side`.

### Netops

| Purpose | Arch | Debian / Ubuntu |
| --- | --- | --- |
| DNS tools | `bind` | `dnsutils` |
| Ping/IP tools | `iproute2`, `iputils` | `iproute2`, `iputils-ping` |
| Trace / latency | `traceroute`, `mtr` | `traceroute`, `mtr-tiny` |
| Packet capture | `tcpdump`, `wireshark-cli` | `tcpdump`, `tshark` |
| Port scanning | `nmap` | `nmap` |
| TLS / SSL testing | `sslscan`, `testssl.sh` | `sslscan`, `testssl.sh` |
| Bandwidth / latency testing | `iperf3`, `fping` | `iperf3`, `fping` |
| Interface tools | `ethtool` | `ethtool` |
| Open ports/processes | `lsof` | `lsof` |
| WHOIS | `whois` | `whois` |
| Netcat / sockets | `openbsd-netcat`, `nmap` for `ncat`, `socat` | `netcat-openbsd`, `ncat`, `socat` |
| ARP discovery | `arp-scan` | `arp-scan` |
| SMB testing | `smbclient` | `smbclient` |
| SNMP | `net-snmp` | `snmp`, `snmp-mibs-downloader` |
| VPN tools | `wireguard-tools`, `openvpn` | `wireguard-tools`, `openvpn` |

Also include `mosh`, `sshfs`, `rsync`, `rclone`, and `rkhunter`. Keep fail2ban in core because SSH protection should be enabled on the baseline install.

### Wireless

The `wireless` profile should install NetworkManager CLI support, WPA backends, Wi-Fi scanning tools, wireless firmware, RF-kill controls, mobile broadband support, and optional tray integration packages where available.

Do not automatically enable `iwd.service`. NetworkManager may be enabled for the `wireless` profile only when it is already active/enabled, when no obvious existing networking stack is detected, or when `LINUX_CLI_ENABLE_NETWORKMANAGER=1` is set. `LINUX_CLI_ENABLE_NETWORKMANAGER=0` must skip NetworkManager service enablement.

Wireless Fish helpers are managed separately from the `comfort` helpers. Keep `wifi-connect.fish` and `wifi-info.fish` tied to the `wireless` profile.

### Storage

The `storage` profile should install filesystem administration, removable-media, SMB/CIFS, encryption, copy progress, recovery, and flash-media verification tools.

| Purpose | Arch | Debian / Ubuntu |
| --- | --- | --- |
| XFS tools | `xfsprogs` | `xfsprogs` |
| Btrfs tools | `btrfs-progs` | `btrfs-progs` |
| FAT tools | `dosfstools` | `dosfstools` |
| exFAT tools | `exfatprogs` | `exfatprogs` |
| NTFS tools | `ntfs-3g` | `ntfs-3g` |
| SMB/CIFS mounts | `cifs-utils` | `cifs-utils` |
| Disk encryption | `cryptsetup` | `cryptsetup` |
| Copy progress | `pv` | `pv` |
| GNU ddrescue | `ddrescue` | `gddrescue` |
| Flash-media validation | `f3` | `f3` |

Arch does not ship `f3` in the official repositories; keep it recommended so the existing `yay` fallback can install the AUR `f3` package.

### Diagnostics

| Purpose | Arch | Debian / Ubuntu |
| --- | --- | --- |
| Hardware listing | `pciutils`, `usbutils`, `lshw`, `dmidecode` | `pciutils`, `usbutils`, `lshw`, `dmidecode` |
| Sensors | `lm_sensors` | `lm-sensors` |
| Disk SMART | `smartmontools` | `smartmontools` |
| NVMe tools | `nvme-cli` | `nvme-cli` |
| Disk/partition tools | `parted`, `gptfdisk` | `parted`, `gdisk` |
| I/O monitoring | `iotop`, `sysstat` | `iotop`, `sysstat` |
| Network usage | `iftop`, `nethogs` | `iftop`, `nethogs` |
| Process tracing | `strace` | `strace` |
| File/process debugging | `lsof`, `psmisc` | `lsof`, `psmisc` |

### Dev

| Purpose | Arch | Debian / Ubuntu |
| --- | --- | --- |
| Python | `python`, `python-pip`, `python-pipx` | `python3`, `python3-pip`, `python3-venv`, `pipx` |
| Fast env/package tool | `uv` | install with `pipx` when apt lacks it |
| Build tools | `base-devel`, `cmake`, `pkgconf` | `build-essential`, `cmake`, `pkg-config` |
| Editor | `neovim` | `neovim` |

Install or upgrade `ruff`, `black`, `pytest`, and `pre-commit` through `pipx`.

### Docker

Docker must be opt-in. On Arch, install `docker`, `docker-compose`, `lazydocker`, `dive`, `ctop`, and `hadolint`, enable Docker, and add the target user to the `docker` group.

On Debian/Ubuntu, prefer Docker's official apt repository for production-style hosts and install Docker Engine, CLI, containerd, Buildx, and the Compose plugin. Support `LINUX_CLI_DOCKER_APT_SOURCE=distro` for a distro-package fallback. Add Docker Fish aliases, but never run Docker prune or destructive cleanup automatically.

### Desktop

Desktop is a small GUI workstation helper profile. Keep it focused on clipboard, desktop integration, and notification utilities unless the user asks for a fuller workstation setup.

## Time And Automatic Updates

- The installer should set the timezone to `America/Detroit`.
- Enable automatic NTP synchronization through chrony. Configure chrony to read DHCP-provided NTP servers from `/run/chrony-dhcp` and use `us.pool.ntp.org` as the public fallback pool. Install managed NetworkManager and dhclient hooks that write DHCP NTP servers into chrony's sourcedir, plus a tmpfiles entry that recreates the runtime directory after reboot. Disable `systemd-timesyncd` and remove the Debian/Ubuntu `systemd-timesyncd` package when present.
- Install and enable fail2ban from core with a managed SSH jail that reads from the systemd journal and bans through UFW.
- Install and configure logrotate from core for `/var/log/linux-cli-setup/*.log`.
- Install `time-status` and `ntp-status` into `/usr/local/bin`.
- Install regular files from `scripts/utilities/` into `/usr/local/bin` as root-owned executable utility commands. Uninstall should remove matching managed utility commands by comparing them against the repository copies and should back up changed local files instead of deleting them. The `aliases` utility must print all Fish abbreviations and aliases visible to the current user.
- Install `/usr/local/sbin/linux-cli-auto-update` and `/etc/linux-cli-setup/auto-update.conf`.
- Never commit real Pushover keys. The config template must contain placeholders only and the installed config must be root-only mode `0600`.
- A root `.auto-update.conf` may exist for local testing with real settings, but it must stay ignored by Git. The installed runtime config is still `/etc/linux-cli-setup/auto-update.conf`.
- The automatic update scheduler should run daily between 3:30 AM and 4:30 AM. Prefer a systemd timer with `OnCalendar=03:30` plus `RandomizedDelaySec=1h`; fall back to `/etc/cron.d/linux-cli-auto-update` when systemd is unavailable.
- Debian/Ubuntu auto-update uses `apt-get update`, `full-upgrade`, `autoremove`, and `autoclean`.
- Arch auto-update uses `pacman -Syu --noconfirm` and may run `yay -Sua --noconfirm` as the configured `AUR_USER` when enabled.

## Security And Safety

- Treat installer changes as security-sensitive. Review privilege boundaries, downloaded assets, file ownership, file modes, shell quoting, package repositories, and service exposure.
- Avoid destructive changes without a backup, state tracking, or an explicit flag.
- Uninstall should remove managed files by default and remove packages only with `--remove-packages`.
- Do not expose stack traces, debug dumps, secrets, or private network details beyond the intended MOTD host-health summary.
- Keep remote downloads on HTTPS URLs from upstream projects and document any new remote source.
- Docker profile may add a high-privilege `docker` group membership; keep it opt-in and document the logout/login requirement.
- UFW setup can affect remote access. Always allow detected SSH ports before enabling UFW and do not reset existing UFW rules.
- NetworkManager can disrupt server networking when enabled blindly. Keep wireless service enablement guarded by the existing-network detection and documented environment overrides.
- Treat Pushover credentials as secrets. If a user pasted credentials in chat or a ticket, do not copy them into repository files; install placeholders and instruct the user to put rotated keys into the root-only config on the host.

## Validation

Before finishing installer changes, run the practical checks available in the current environment:

```bash
for file in install.sh update.sh uninstall.sh install_test.sh scripts/setup-linux-cli.sh scripts/uninstall-linux-cli.sh scripts/install-test-linux-cli.sh scripts/lib/linux-cli-common.sh scripts/lib/package-install-overrides.sh scripts/utilities/* templates/motd/linux-cli-motd templates/bin/time-status templates/bin/ntp-status templates/auto-update/linux-cli-auto-update templates/chrony/chrony-dhcp-source templates/chrony/networkmanager-dispatcher templates/chrony/dhclient-exit-hook; do bash -n "$file"; done
for file in templates/fish/config.fish templates/fish/configure_tide.fish templates/fish/conf.d/linux-cli-motd.fish templates/fish/functions/*.fish; do fish -n "$file"; done
shellcheck install.sh update.sh uninstall.sh install_test.sh scripts/setup-linux-cli.sh scripts/uninstall-linux-cli.sh scripts/install-test-linux-cli.sh scripts/lib/linux-cli-common.sh scripts/lib/package-install-overrides.sh scripts/utilities/* templates/motd/linux-cli-motd templates/bin/time-status templates/bin/ntp-status templates/auto-update/linux-cli-auto-update templates/chrony/chrony-dhcp-source templates/chrony/networkmanager-dispatcher templates/chrony/dhclient-exit-hook
./install.sh --list-profiles
./install.sh --help
./install.sh --version
./update.sh --help
./update.sh --version
./uninstall.sh --help
./uninstall.sh --version
./install_test.sh --help
./install_test.sh --version
```

If Fish or ShellCheck is not installed locally, state which validation could not be run. Do not run the full installer on the development machine unless the user explicitly asks for it.

## Documentation Rules

- Keep `README.md` user-facing and reasonably concise, but keep profile/package behavior discoverable.
- Update `CHANGELOG.md` for every meaningful code or behavior change.
- Update this file when installer behavior, architecture, workflows, security posture, profile contents, package mappings, or validation steps change.
- Create focused docs under `docs/` only when this file becomes too large or a specialized workflow needs more detail.
