# AGENTS.md

This is the first-read guide for agents working in `linux-cli-setup`. Read this file before changing code, templates, package lists, or documentation.

## Project Purpose

This project provides root-run Linux setup, update, and uninstall scripts for CLI-focused systems. It supports Arch-based systems with `pacman`/`yay` and Debian/Ubuntu-based systems with `apt`. The default install is the `core` profile; optional profiles add development, network troubleshooting, diagnostics, Docker host, and desktop workstation tooling.

## Repository Map

- `install.sh`, `update.sh`, and `uninstall.sh` are root entry points. Keep them small wrappers.
- `VERSION` is the project version source. Update it with every release or prerelease.
- `scripts/setup-linux-cli.sh` contains the install flow.
- `scripts/update-linux-cli.sh` contains the update flow.
- `scripts/uninstall-linux-cli.sh` contains the uninstall flow.
- `scripts/lib/linux-cli-common.sh` contains shared profile, package, distro, user, Fish, Git, MOTD, Docker, and safety helpers.
- `templates/fish/` contains Fish, Fisher, Tide, abbreviation, and fallback MOTD hook templates.
- `templates/motd/linux-cli-motd` contains the dynamic MOTD script installed on target systems.
- `templates/bin/` contains installed CLI status commands such as `time-status` and `ntp-status`.
- `templates/auto-update/` contains the installed automatic update script and root-only config template.
- `templates/systemd/` and `templates/cron/` contain automatic update scheduling templates.
- `README.md` is the user-facing overview and usage guide.
- `CHANGELOG.md` records notable changes because this project is not currently versioned.

## Profile Contract

Do not collapse this project into one giant "install everything" profile. Keep `core` as the always-installed baseline and keep heavier tools behind profiles:

| Profile | Role |
| --- | --- |
| `core` | Always-installed CLI baseline, Fish prompt, Git defaults, MOTD, and distro helpers. |
| `dev` | Python, C/C++ build tools, Neovim, uv, pipx tools, and developer Git helpers. |
| `netops` | DNS, packet capture, port scanning, VPN, SSH, transfer, and MSP troubleshooting tools. |
| `diagnostics` | Hardware, disk, sensor, I/O, network usage, tracing, and process diagnostics. |
| `docker` | Docker host packages, Compose plugin, Docker CLI helpers, and Fish Docker aliases. |
| `desktop` | GUI workstation clipboard, desktop integration, and notification helpers. |

`install.sh` and `update.sh` always include `core`; optional profiles are selected with `--profile`, `--profiles`, or `--all-profiles`. `uninstall.sh --remove-packages` does not implicitly add `core`, because package removal is destructive.

## Installer Contract

- The installer must be run as root, normally through `sudo ./install.sh`.
- The target account is the sudoing user from `$SUDO_USER`, not `root`. Root-only direct runs must require `TARGET_USER=username` or saved state.
- Package-family detection should stay conservative: prefer `pacman` for Arch-based systems and `apt-get` for Debian/Ubuntu-based systems.
- Arch installs must ensure `yay` is available before AUR fallback installs.
- Debian/Ubuntu scripts must use noninteractive `apt-get`. Installing `nala` is fine, but scripts must not depend on it.
- Existing user Fish files must be backed up before replacement unless the installed file already matches the project template.
- Fish should become the target user's default shell through `/etc/shells` plus `chsh` or `usermod`.
- Install state belongs in `/var/lib/linux-cli-setup/install.env`; preserve the originally saved shell across updates.
- Script logs belong in `/var/log/linux-cli-setup/`; create one log file per install, update, uninstall, or auto-update execution.
- Package-manager output must stay suppressed by default. Console output should show each item being installed, updated, or uninstalled, with colored status lines unless `--no-color` is passed.
- Executable script options must use long `--option` names only. Keep `--help` and `--version` on executable scripts.
- `--debug` must show captured command output and command details in both console and log files.
- Required install/update failures must print the error and the last captured output for the failing item, then roll back managed changes from that run. Package-manager system upgrades are not fully reversible; document that limit instead of pretending otherwise.
- Uninstall must keep going after individual errors and report warnings instead of aborting the whole run.
- Do not hardcode secrets, private URLs, credentials, tokens, or environment-specific host names.

## Package Recommendations

Keep these package mappings aligned across code and README.

### Core

Core always includes OpenSSH, Git, Fish, htop, btop, JetBrainsMono Nerd Font Mono, Fisher, Tide, prompt config, and MOTD.

| Purpose | Arch / Garuda | Debian / Ubuntu |
| --- | --- | --- |
| Downloads / repos | `curl`, `wget`, `ca-certificates`, `gnupg` | `curl`, `wget`, `ca-certificates`, `gnupg` |
| Archives | `unzip`, `zip`, `p7zip`, `tar`, `gzip`, `xz` | `unzip`, `zip`, `p7zip-full`, `tar`, `gzip`, `xz-utils` |
| Terminal multiplexer | `tmux` | `tmux` |
| Search / navigation | `ripgrep`, `fd`, `fzf`, `plocate` | `ripgrep`, `fd-find`, `fzf`, `plocate` |
| File viewing | `bat`, `eza`, `tree`, `less` | `bat`, `eza`, `tree`, `less` |
| JSON / YAML | `jq`, `yq` | `jq`, `yq` |
| Disk usage | `ncdu`, `duf`, `dust` | `ncdu`, `duf` |
| Logs | `lnav` | `lnav` |
| Docs / help | `man-db`, `man-pages`, `tldr` | `man-db`, `manpages`, `tldr` |
| System info | `fastfetch`, `inxi` | `fastfetch`, `inxi` |
| Dotfiles | `chezmoi` | `chezmoi` |

Arch-specific core additions are `pacman-contrib`, `reflector`, `pkgfile`, and `base-devel`. Enable `paccache.timer` and run `pkgfile -u` when available.

Debian/Ubuntu-specific additions are `apt-file`, `needrestart`, `debian-goodies`, `software-properties-common`, `apt-transport-https`, `unattended-upgrades`, and `nala`.

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
| Bandwidth testing | `iperf3` | `iperf3` |
| Interface tools | `ethtool` | `ethtool` |
| Open ports/processes | `lsof` | `lsof` |
| WHOIS | `whois` | `whois` |
| Netcat / sockets | `openbsd-netcat`, `socat` | `netcat-openbsd`, `socat` |
| ARP discovery | `arp-scan` | `arp-scan` |
| SMB testing | `smbclient` | `smbclient` |
| SNMP | `net-snmp` | `snmp`, `snmp-mibs-downloader` |
| VPN tools | `wireguard-tools`, `openvpn` | `wireguard-tools`, `openvpn` |

Also include `mosh`, `sshfs`, `rsync`, `rclone`, and `fail2ban`.

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
- Enable automatic NTP synchronization. On systemd systems, prefer DHCP-provided NTP servers and use `us.pool.ntp.org` as the fallback pool through `systemd-timesyncd`.
- Install `time-status` and `ntp-status` into `/usr/local/bin`.
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
- Treat Pushover credentials as secrets. If a user pasted credentials in chat or a ticket, do not copy them into repository files; install placeholders and instruct the user to put rotated keys into the root-only config on the host.

## Validation

Before finishing installer changes, run the practical checks available in the current environment:

```bash
bash -n install.sh update.sh uninstall.sh scripts/setup-linux-cli.sh scripts/update-linux-cli.sh scripts/uninstall-linux-cli.sh scripts/lib/linux-cli-common.sh templates/motd/linux-cli-motd templates/bin/time-status templates/bin/ntp-status templates/auto-update/linux-cli-auto-update
fish -n templates/fish/config.fish templates/fish/configure_tide.fish templates/fish/conf.d/linux-cli-motd.fish
shellcheck install.sh update.sh uninstall.sh scripts/setup-linux-cli.sh scripts/update-linux-cli.sh scripts/uninstall-linux-cli.sh scripts/lib/linux-cli-common.sh templates/motd/linux-cli-motd templates/bin/time-status templates/bin/ntp-status templates/auto-update/linux-cli-auto-update
./install.sh --list-profiles
./install.sh --help
./install.sh --version
./update.sh --help
./update.sh --version
./uninstall.sh --help
./uninstall.sh --version
```

If Fish or ShellCheck is not installed locally, state which validation could not be run. Do not run the full installer on the development machine unless the user explicitly asks for it.

## Documentation Rules

- Keep `README.md` user-facing and reasonably concise, but keep profile/package behavior discoverable.
- Update `CHANGELOG.md` for every meaningful code or behavior change.
- Update this file when installer behavior, architecture, workflows, security posture, profile contents, package mappings, or validation steps change.
- Create focused docs under `docs/` only when this file becomes too large or a specialized workflow needs more detail.
