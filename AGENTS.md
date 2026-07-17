# AGENTS.md

This is the first-read guide for agents working in `linux-cli-setup`. Read this file before changing code, templates, package lists, or documentation.

## Project Purpose

This project provides root-run Linux install, non-destructive update, and uninstall scripts for CLI-focused systems. It supports Arch-based systems with `pacman` plus `yay` for AUR-backed optional tools, and Debian/Ubuntu-based systems with `apt`. The default fresh install is the `core` profile; optional profiles add CLI comfort tools, development, network troubleshooting, wireless support, storage/filesystem tooling, diagnostics, Docker host, and desktop workstation tooling.

## Repository Map

- `install.sh`, `update.sh`, and `uninstall.sh` are root entry points. Keep them small wrappers. Install and update share `scripts/setup-linux-cli.sh`, but their state and mutation contracts are distinct.
- `install_test.sh` is the non-mutating package availability diagnostic entry point.
- `VERSION` is the project version source. Update it with every release or prerelease.
- `data/package-groups.yaml` is the editable package group map. Scripts read package names from this file at runtime.
- `scripts/setup-linux-cli.sh` contains the distinct install and saved-profile update flow.
- `scripts/uninstall-linux-cli.sh` contains the uninstall flow.
- `scripts/install-test-linux-cli.sh` contains the package availability diagnostic flow.
- `scripts/lib/linux-cli-common.sh` contains shared profile, package, distro, user, Fish, Git, MOTD, Docker, and safety helpers.
- `scripts/lib/package-install-overrides.sh` contains runtime install overrides for availability-aware package installs and installed utility commands.
- `scripts/utilities/` contains managed utility commands copied to `/usr/local/bin`, including `aliases`, `timecheck`, `updatecheck`, `internetcheck`, `needs-reboot`, `lcsversion`, and `dockercheck`.
- `templates/fish/` contains Fish, Fisher, Tide, abbreviation, and fallback MOTD hook templates.
- `templates/sysctl/` contains managed sysctl hardening and performance templates.
- `templates/ssh/sshd_config.d/` contains managed OpenSSH daemon hardening snippets.
- `templates/apt/` contains managed Debian/Ubuntu apt hardening snippets.
- `templates/motd/linux-cli-motd` contains the dynamic MOTD script installed on target systems, and `templates/motd/unifetch-motd.conf` contains the managed UniFetch MOTD config.
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
| `netops` | DNS, packet capture, port scanning, SSH, transfer, and MSP troubleshooting tools. |
| `wireless` | NetworkManager, Wi-Fi scanning, firmware, RF-kill, mobile broadband, and wireless CLI helpers. |
| `storage` | Filesystem, removable media, SMB/CIFS, encryption, recovery, and flash-media tools. |
| `diagnostics` | Hardware, disk, sensor, I/O, network usage, tracing, and process diagnostics. |
| `docker` | Docker host packages, Compose plugin, Docker CLI helpers, and Fish Docker aliases. |
| `desktop` | GUI workstation clipboard, desktop integration, and notification helpers. |

`install.sh` always includes `core`; optional profiles are selected with `--profile`, `--profiles`, or `--all-profiles`. If saved install state exists, `install.sh` must exit and direct the operator to `update.sh`. If saved install state does not exist, `update.sh` must exit and direct the operator to `install.sh`.

When `install.sh` is run without an explicit profile option and no install state exists, install `core` only. Do not prompt for optional profiles. Keep `diagnostics` available for backward-compatible explicit use with `--profile diagnostics`.

Keep `core` first in install, update execution order, and saved state. `update.sh` should update all saved profiles and merge explicitly requested profiles into saved state instead of dropping earlier selections. `uninstall.sh --remove-packages` should default to saved profiles, including `core`, and avoid removing packages that belong to retained profiles only when the user explicitly selects a subset.

## Installer Contract

- The installer must be run as root, normally through `sudo ./install.sh`.
- The target account is the sudoing user from `$SUDO_USER`, not `root`. Root-only direct runs must require `TARGET_USER=username` or saved state.
- Package-family detection should stay conservative: prefer `pacman` for Arch-based systems and `apt-get` for Debian/Ubuntu-based systems.
- Install, update, uninstall, and package availability tests must fail clearly on systems without `pacman` or `apt-get`. Install/update/uninstall should run this support check after root/log initialization and before GitHub self-update or managed-file changes.
- Arch installs must ensure `yay` is available before profile packages are installed. Arch package rows may use pacman packages or AUR packages installable through `yay`; keep AUR-only packages in recommended rows unless the user explicitly asks for a required AUR package.
- Debian/Ubuntu scripts must use noninteractive `apt-get`. Installing `nala` is fine, but scripts must not depend on it.
- Fresh install should back up existing user Fish files before replacement unless the installed file already matches the project template. Update must preserve existing configuration files byte-for-byte and install only missing structured configuration files. Only safely parsed, simple key/value files such as `/etc/auto-update.conf` may receive missing settings additively; never line-merge structured Fish, SSH, systemd, chrony, MOTD, sysctl, firewall, or hardening configuration.
- Fish should become the target user's default shell through `/etc/shells` plus `chsh` or `usermod`.
- Install state belongs in `/var/lib/linux-cli-setup/install.env`; preserve the originally saved shell across updates and store the installed project version. Also install the version at `/usr/local/share/linux-cli-setup/VERSION` for `lcsversion`.
- Package group contents belong in `data/package-groups.yaml`, not hardcoded shell case blocks. Keep the YAML structure simple: one item per group/tier row, distro-specific package names as one-per-line lists under `arch` and `debian_ubuntu`, and short single-line notes.
- Script logs belong in `/var/log/linux-cli-setup/`; create one log file per install, update, uninstall, or auto-update execution. Install, update, and uninstall must print the exact persistent log path at the end of successful, failed, and interrupted runs.
- `install_test.sh` may run without root and may fall back to a repository-local `logs/` directory when `/var/log/linux-cli-setup/` is not writable. It must not install, update, remove, enable, or disable anything. On Arch, it may use installed yay or the read-only AUR RPC to verify optional AUR package names.
- Package-manager output must stay suppressed by default. Console output should show each item being installed, updated, or uninstalled, including the owning package profile as `profile/package` when a profile package is being processed. Action/status lines should use a readable bright color, not dark blue, unless `--no-color` is passed.
- Executable script options must use long `--option` names only. Keep `--help` and `--version` on executable scripts.
- After root detection and log initialization, install, update, and uninstall must check GitHub releases and prereleases for a newer project version before making system changes. Limit the initial release lookup to 10 seconds; if it times out without a response, warn and continue with the running version. If a newer version is available, fetch and pull from the trusted `cosmicc/linux-cli-setup` `origin/main`, show Git progress, create a temporary restart wrapper under `/tmp`, and exec the same entrypoint with the original arguments. Keep `LINUX_CLI_SELF_UPDATE_RESTARTED=1` as the loop guard.
- Self-update version ordering must support alpha and beta prerelease labels such as `0.1a` and `0.5b`, with final releases such as `v1.0` ranking after prereleases at the same numeric version. Do not auto-update from an unexpected GitHub remote.
- `--debug` must show captured command output and command details in both console and log files.
- Required install/update failures must print the error and the last captured output for the failing item, then roll back managed changes from that run. Install and uninstall transactions must also trap unexpected nonzero exits plus `SIGHUP`, `SIGINT`, `SIGQUIT`, and `SIGTERM`, run rollback before exiting, skip over rollback-command errors, and preserve the original or conventional signal-derived exit code. Package-manager system upgrades are not fully reversible; document that limit instead of pretending otherwise.
- Install and update should run performance and hardening checks by default. `--skip-performance` must skip the performance section, and `--skip-hardening` must skip firewall, fail2ban, sysctl, OpenSSH daemon, and apt hardening checks. Update must preserve existing configuration and UFW rules.
- The hardening section should configure UFW after OpenSSH is enabled. Preserve existing UFW rules, set default deny incoming/default allow outgoing, allow SSH, allow iperf3 on TCP/UDP `5201`, and keep ICMP echo-request ping allowed.
- Install and update should apply only basic, non-obtrusive OS hardening. Hardening must be best-effort and must not abort the operation.
- The performance section should stay conservative: managed sysctl values, systemd `fstrim.timer` when available, and no hardware-specific CPU, mount, or I/O scheduler changes without an explicit user request.
- Fresh install may remove unused packages and clean package caches near the end of the run. Update must not run apt autoremove or remove Arch orphan packages; it may clean package caches. Cleanup failures should warn and continue.
- Uninstall must keep going after individual errors and report warnings instead of aborting the whole run.
- Full package removal must remain behind the explicit `--remove-packages` flag. Exact restoration of package-manager upgrades, firewall state, time settings, service enablement, and packages that predated linux-cli-setup is not guaranteed unless the project has tracked that specific prior state.
- Do not hardcode secrets, private URLs, credentials, tokens, or environment-specific host names.

## Package Recommendations

Keep these package mappings aligned with `data/package-groups.yaml`. The YAML file is authoritative for script behavior; these tables are explanatory documentation.

### Core

Core always includes OpenSSH, Git, Vim, NFS client support, UFW firewall, chrony, fail2ban, logrotate, `dig`, `fping`, `iproute2`, Fish, htop, btop, JetBrainsMono Nerd Font Mono, Fisher, Tide, prompt config, and MOTD.

| Purpose | Arch / Garuda | Debian / Ubuntu |
| --- | --- | --- |
| Downloads / repos | `curl`, `wget`, `ca-certificates`, `gnupg` | `curl`, `wget`, `ca-certificates`, `gnupg` |
| Archives | `unzip`, `zip`, `7zip`, `tar`, `gzip`, `xz` | `unzip`, `zip`, `p7zip-full`, `tar`, `gzip`, `xz-utils` |
| Terminal multiplexer | `tmux` | `tmux` |
| Baseline editor | `vim` | `vim` |
| NFS client support | `nfs-utils` | `nfs-common` |
| Firewall | `ufw` | `ufw` |
| DNS / latency / IP | `bind`, `fping`, `iproute2` | `bind9-dnsutils`, `fping`, `iproute2` |
| Search / navigation | `ripgrep`, `fd`, `fzf`, `plocate` | `ripgrep`, `fd-find`, `fzf`, `plocate` |
| File viewing | `bat`, `eza`, `tree`, `less` | `bat`, `eza`, `tree`, `less` |
| JSON / YAML | `jq`, `yq` | `jq`, `yq` |
| Disk usage | `ncdu`, `duf`, `dust` | `ncdu`, `duf` |
| Logs | `lnav` | `lnav` |
| Docs / help | `man-db`, `man-pages`, `tldr` | `man-db`, `manpages`, `tealdeer` |
| System info / MOTD | `fastfetch`, `unifetch`, `inxi` | `fastfetch`, `inxi` |
| Dotfiles | `chezmoi` | not packaged in Debian stable |
| Time sync / SSH protection / log rotation | `chrony`, `fail2ban`, `logrotate` | `chrony`, `fail2ban`, `logrotate` |
| Security audit / integrity | `lynis`, `aide` | `lynis`, `aide` |
| Transfer / throughput | `rsync`, `pv` | `rsync`, `pv` |
| System and network monitors | `glances`, `atop`, `dool`, `vnstat`, `bmon` | `glances`, `atop`, `vnstat`, `bmon` |
| Nerd Font package | `ttf-jetbrains-mono-nerd` | installed from Nerd Fonts release fallback |

Arch-specific core additions are `pacman-contrib`, `reflector`, `pkgfile`, and `base-devel`. Enable `paccache.timer` and run `pkgfile -u` when available.

Debian/Ubuntu-specific additions are `apt-file`, `needrestart`, `debian-goodies`, `apt-transport-https`, `unattended-upgrades`, and `nala`.

Do not keep package-map entries for packages that are missing from the selected system's normal package sources. For Arch, normal sources include pacman and AUR via yay. Docker's Debian/Ubuntu official-repository packages are the only Debian/Ubuntu exception because the Docker profile adds that repository before installing them.

### Comfort

The `comfort` profile is the optional CLI workflow layer. It should prefer distro packages from `data/package-groups.yaml`, then attempt user-level cargo or pipx fallback installs only for missing tools where a known package/crate mapping exists. Cargo source-build fallbacks are enabled by default and may be skipped with `LINUX_CLI_ENABLE_CARGO_FALLBACKS=0`. Debian/Ubuntu comfort installs must include source-build prerequisites such as `build-essential`, `pkg-config`, and `libssl-dev` before cargo fallbacks run. For cargo tools whose current crates require a newer Rust compiler than a supported distro commonly ships, pin a tested compatible crate version instead of repeatedly failing on MSRV errors. Keep fallback installs best-effort and non-system-wide.

Comfort includes Fish integrations for `atuin`, `zoxide`, `direnv`, and `mise` when those commands exist. Keep Tide as the prompt because the project intentionally uses Fish + Tide to match the screenshot. Do not switch to Starship unless the user explicitly asks.

Managed Fish functions live under `templates/fish/functions/` and are installed into the target user's `~/.config/fish/functions/`. The managed `fish_prompt.fish` must use Tide's generated prompt-loader pattern from the reference system, including the per-session `_tide_prompt_$fish_pid` variable, so the prompt is rebuilt from Tide items instead of a stale hardcoded cache variable. The Tide variables in `templates/fish/configure_tide.fish` must produce the reference two-line prompt with OS/current directory and Git status on the left, rounded prompt segment caps, a horizontal frame, a rounded right prompt with command-duration, context, jobs, environment, language/toolchain, cloud, Kubernetes, container, and time items, and the prompt character on the second line. The Git prompt item must use the Nerd Font git icon, not a text `git` label. Tool-specific Tide items should stay hidden until their supporting command and project marker or environment are present. The command-duration segment should appear only after commands longer than the configured Tide threshold. Fresh install applies Tide settings and the managed prompt after Fisher installs Tide. Update refreshes registered Fisher plugins while preserving existing Tide and Fish configuration files. The non-interactive Tide configuration script must exit successfully after applying settings even when Tide's optional OS detection function is unavailable. The managed prompt must keep login usable with a basic fallback prompt when Tide helpers are missing. The default managed Fisher plugin list is `jorgebucaran/fisher`, `IlanCosman/tide@v6`, `patrickf1/fzf.fish`, `jorgebucaran/autopair.fish`, `edc/bass`, and `franciscolourenco/done`; keep these enabled by default unless the user asks to remove one. Managed SSH client defaults live under `templates/ssh/`; install them through an include file under `~/.ssh/conf.d/` and never modify an existing `~/.ssh/config` during update.

Do not install the managed `fish_prompt.fish` before Fisher has installed or refreshed Tide. Tide ships its own `fish_prompt.fish`, and Fisher treats a pre-existing prompt file as a conflict when Tide is not already registered. The installer should prepare known unmanaged Fisher conflicts, install the full managed plugin list in one pass, verify the required `_tide_*` helper functions, configure Tide variables, and only then install the managed prompt template.

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
| Ping tools | `iputils` | `iputils-ping` |
| Trace / latency | `traceroute`, `mtr` | `traceroute`, `mtr-tiny` |
| Packet capture | `tcpdump`, `wireshark-cli` | `tcpdump`, `tshark` |
| Port scanning | `nmap` | `nmap` |
| TLS / SSL testing | `sslscan`, `testssl.sh` | `sslscan`, `testssl.sh` |
| Bandwidth testing | `iperf3` | `iperf3` |
| Interface tools | `ethtool` | `ethtool` |
| Open ports/processes | `lsof` | `lsof` |
| WHOIS | `whois` | `whois` |
| Netcat / sockets | `openbsd-netcat`, `nmap` for `ncat`, `socat` | `netcat-openbsd`, `ncat`, `socat` |
| ARP discovery | `arp-scan` | `arp-scan` |
| ARP reachability | `iputils` provides `arping` | `arping` |
| SMB testing | `smbclient` | `smbclient` |

Also include `mosh`, `sshfs`, `rclone`, and `rkhunter`. Keep `dig`, `fping`, `iproute2`, `rsync`, and fail2ban in core because baseline diagnostics, transfer support, and SSH protection depend on them.

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

On Debian/Ubuntu, prefer Docker's official apt repository for production-style hosts and install Docker Engine, CLI, containerd, Buildx, and the Compose plugin. Support `LINUX_CLI_DOCKER_APT_SOURCE=distro` for a distro-package fallback with `docker.io` and `docker-compose`. Add Docker Fish aliases, but never run Docker prune or destructive cleanup automatically.

### Desktop

Desktop is a small GUI workstation helper profile. Keep it focused on clipboard, desktop integration, and notification utilities unless the user asks for a fuller workstation setup.

## Time And Automatic Updates

- The installer should set the timezone to `America/Detroit`.
- Enable automatic NTP synchronization through chrony. Configure chrony to read DHCP-provided NTP servers from `/run/chrony-dhcp` and use `us.pool.ntp.org` as the public fallback pool. Install managed NetworkManager and dhclient hooks that write DHCP NTP servers into chrony's sourcedir, plus a tmpfiles entry that recreates the runtime directory after reboot. Disable `systemd-timesyncd` and remove the Debian/Ubuntu `systemd-timesyncd` package when present.
- Install and enable fail2ban from core with a managed SSH jail that reads from the systemd journal and bans through UFW.
- Install and configure logrotate from core for `/var/log/linux-cli-setup/*.log`.
- The hardening section also installs managed sysctl protections, conservative OpenSSH daemon guardrails, and Debian apt settings that reject unauthenticated or insecure repositories.
- The performance tuning section installs managed sysctl tuning for file watchers, file handles, cache pressure, dirty page writeback, service backlog, and MTU probing, and enables `fstrim.timer` when available.
- Install `time-status` and `ntp-status` into `/usr/local/bin`.
- Install regular files from `scripts/utilities/` into `/usr/local/bin` as root-owned executable utility commands during both install and update. Uninstall should remove matching managed utility commands by comparing them against the repository copies and should back up changed local files instead of deleting them, except `lcsversion` remains so it can report the uninstalled state. The `aliases` utility must print all Fish abbreviations and aliases visible to the current user. The `timecheck` utility must show chrony/NTP status, selected time source, and stratum; install `/usr/local/bin/ntpcheck` as a managed alias symlink to `timecheck`. `updatecheck` must list OS package updates and obtain confirmation before installing them. `internetcheck` must use bounded probes for external IP, fping latency, configured DNS-server reachability and dig latency, and Cloudflare download/upload throughput. `needs-reboot` must return `1` when a Debian/Ubuntu reboot marker exists or a monitored kernel/core system component was updated after boot. The Docker utility is named `dockercheck`.
- MOTD behavior is controlled by `--motd keep`, `--motd replace`, or `--motd combine`. `replace` is the noninteractive default and should hide existing MOTD entries before showing linux-cli-setup. `keep` should leave the existing login MOTD alone and remove linux-cli-setup login MOTD hooks. `combine` should show the existing MOTD first and linux-cli-setup afterward. If no MOTD option or `LINUX_CLI_MOTD_MODE` value is provided in an interactive install and no saved mode exists, prompt for the mode. Update should reuse `motd_mode` from install state unless the user passes a new mode, refresh MOTD executables, and preserve existing MOTD configuration and enablement choices. When a preserved legacy UniFetch config lacks newer status fields, the managed MOTD executable should append the extended status block without modifying that config. The installed MOTD should prefer UniFetch with OS-matched ASCII art, then fall back to the built-in linux-cli-setup status block when it is unavailable or fails. Both paths should show OS and kernel details, memory, distinct mounted local filesystems, currently mounted NFS filesystems, remaining storage, local IP, internet/public-IP status, load average, cached package-update status, UFW and SSH status, and reboot requirement. Do not activate dormant automounts or perform a package metadata refresh from the MOTD. Keep network, storage, and local status probes bounded by short timeouts so login remains responsive. Arch/Garuda may install optional UniFetch through pacman or yay/AUR. Debian/Ubuntu must not add a third-party UniFetch repository.
- Install `/usr/local/bin/auto-update` and `/etc/auto-update.conf`. Fresh install may migrate managed legacy paths from `/usr/local/sbin/linux-cli-auto-update` and `/etc/linux-cli-setup/auto-update.conf`; update preserves legacy files.
- Never commit real Pushover keys. The config template must contain placeholders only and the installed config must be root-only mode `0600`.
- A root `.auto-update.conf` may exist for local testing with real settings, but it must stay ignored by Git. The installed runtime config is `/etc/auto-update.conf`.
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
for file in install.sh update.sh uninstall.sh install_test.sh scripts/setup-linux-cli.sh scripts/uninstall-linux-cli.sh scripts/install-test-linux-cli.sh scripts/lib/linux-cli-common.sh scripts/lib/package-install-overrides.sh scripts/utilities/* templates/motd/linux-cli-motd templates/motd/unifetch-motd.conf templates/bin/time-status templates/bin/ntp-status templates/auto-update/auto-update templates/auto-update/auto-update.conf templates/chrony/chrony-dhcp-source templates/chrony/networkmanager-dispatcher templates/chrony/dhclient-exit-hook; do bash -n "$file"; done
for file in templates/fish/config.fish templates/fish/configure_tide.fish templates/fish/conf.d/linux-cli-motd.fish templates/fish/functions/*.fish; do fish -n "$file"; done
shellcheck install.sh update.sh uninstall.sh install_test.sh scripts/setup-linux-cli.sh scripts/uninstall-linux-cli.sh scripts/install-test-linux-cli.sh scripts/lib/linux-cli-common.sh scripts/lib/package-install-overrides.sh scripts/utilities/* templates/motd/linux-cli-motd templates/motd/unifetch-motd.conf templates/bin/time-status templates/bin/ntp-status templates/auto-update/auto-update templates/auto-update/auto-update.conf templates/chrony/chrony-dhcp-source templates/chrony/networkmanager-dispatcher templates/chrony/dhclient-exit-hook
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
