# Linux CLI Setup

Group-based setup scripts for Arch-based and Debian/Ubuntu-based Linux systems. A fresh install defaults to a safe `core` CLI baseline; heavier roles such as CLI comfort tools, development, network troubleshooting, wireless support, storage/filesystem tooling, Docker hosting, and desktop helpers are optional package groups.

Current unreleased alpha testing version: `0.4a`.

## Supported Systems

- Arch-based systems with `pacman`; the installer bootstraps `yay` before profile packages so AUR-backed optional tools can be installed too.
- Debian/Ubuntu-based systems with `apt`; scripts use `apt-get` even when `nala` is installed for interactive use.

On systems without `pacman` or `apt-get`, `install.sh`, `update.sh`, and `uninstall.sh` stop before self-update or managed-file changes and report that the system is unsupported.

## Quick Start

Run from the user account that should receive Fish as the default shell:

```bash
sudo ./install.sh
```

Without profile options, a fresh install installs `core` only. If linux-cli-setup was already installed, `install.sh` uses the saved profiles and refreshes that installation. The script targets the sudoing user from `$SUDO_USER`, not `root`. If you must run as root directly, set the target user:

```bash
TARGET_USER=myuser ./install.sh
```

## Package Groups

`core` is always included. Add optional groups noninteractively with `--profile` or install every supported group with `--all-profiles`.

```bash
sudo ./install.sh --profile dev,netops
sudo ./install.sh --profile comfort
sudo ./install.sh --profile wireless
sudo ./install.sh --profile storage
sudo ./install.sh --profile docker
sudo ./install.sh --all-profiles
```

Package names are read from [data/package-groups.yaml](data/package-groups.yaml). Edit that file to change which Arch or Debian/Ubuntu packages belong to each group. The YAML file keeps package names as one-per-line lists so manual edits are easier to review than the old tab-delimited map.

Package status lines show the owning profile for package actions, such as `core/curl` or `netops/nmap`. Use `--debug` to show captured package-manager output in the console and log file. Use `--no-color` to disable colored console output.
Performance tuning and hardening are enabled by default. Use `--skip-performance` or `--skip-hardening` when you need to leave those settings untouched for a specific host.

Before install, saved-profile refresh, or uninstall makes system changes, the script checks GitHub releases and prereleases for a newer `linux-cli-setup` version. If a newer version exists, it fetches and pulls from `origin/main` with Git progress shown, then restarts the same command from a temporary wrapper in `/tmp`. Set `LINUX_CLI_SKIP_SELF_UPDATE=1` only for troubleshooting when you intentionally need to run the local checkout as-is. If an install, refresh, or uninstall fails, exits nonzero, or is interrupted with Ctrl+C or a termination signal, the active transaction rolls back before the script exits and skips over rollback errors so cleanup can continue.

Show the script version:

```bash
./install.sh --version
./update.sh --version
./uninstall.sh --version
./install_test.sh --version
```

Available profiles:

| Profile | Purpose |
| --- | --- |
| `core` | Always-installed CLI baseline, Fish prompt, Git defaults, MOTD, and distro helpers. |
| `comfort` | CLI workflow helpers, safer shell shortcuts, Fish functions, and SSH client defaults. |
| `dev` | Python, C/C++ build tools, Neovim, uv, pipx tools, and developer Git helpers. |
| `netops` | DNS, packet capture, port scanning, SSH, transfer, and MSP troubleshooting tools. |
| `wireless` | NetworkManager, Wi-Fi scanning, firmware, RF-kill, mobile broadband, and wireless CLI helpers. |
| `storage` | Filesystem, removable media, SMB/CIFS, encryption, recovery, and flash-media tools. |
| `diagnostics` | Hardware, disk, sensor, I/O, network usage, tracing, and process diagnostics. Explicit-only for compatibility. |
| `docker` | Docker host packages, Compose plugin, Docker CLI helpers, and Fish Docker aliases. |
| `desktop` | GUI workstation clipboard, desktop integration, and notification helpers. |

## Core Install

The `core` profile installs OpenSSH, Git, Vim, NFS client support, UFW firewall, chrony, fail2ban, logrotate, Fish, htop, btop, JetBrainsMono Nerd Font Mono, Fisher, Tide, a screenshot-inspired Fish prompt with rounded left and right status segments, including Git status, long-command duration, and project/toolchain indicators when Tide detects them, and a dynamic MOTD. Rerunning install refreshes the Tide settings and managed prompt file. The installer lets Fisher install Tide first, verifies Tide helpers, and then reapplies the managed prompt. If Tide helper functions are missing, the managed prompt falls back to a basic Fish prompt instead of printing login errors. The managed Fisher plugin set installed by default is Fisher, Tide, fzf.fish, autopair.fish, bass, and done.

It also adds common CLI tools:

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
| Docs / help | `man-db`, `man-pages`, `tldr` | `man-db`, `manpages`, `tealdeer` |
| System info | `fastfetch`, `inxi` | `fastfetch`, `inxi` |
| Dotfiles | `chezmoi` | not packaged in Debian stable |
| Time sync / SSH protection / log rotation | `chrony`, `fail2ban`, `logrotate` | `chrony`, `fail2ban`, `logrotate` |
| Security audit / integrity | `lynis`, `aide` | `lynis`, `aide` |
| Transfer / throughput | `rsync`, `pv` | `rsync`, `pv` |
| System and network monitors | `glances`, `atop`, `dool`, `vnstat`, `bmon` | `glances`, `atop`, `vnstat`, `bmon` |
| Nerd Font package | `ttf-jetbrains-mono-nerd` | installed from Nerd Fonts release fallback |

Recommended package rows are best-effort. On Arch, the installer checks pacman first and falls back to yay/AUR for optional tools such as `aide` when needed. Docker's Debian/Ubuntu profile can add Docker's official apt repository before installing Docker Engine packages.

The installer configures UFW with a default deny incoming policy, default allow outgoing policy, and explicit inbound allowances for SSH, iperf3 on port `5201` TCP/UDP, and ICMP echo-request ping. It does not reset pre-existing UFW rules.

Install and saved-profile refresh also run clear performance and hardening sections. Performance tuning installs conservative sysctl defaults for file watchers, file handles, cache pressure, dirty page writeback, local service backlog, and MTU probing, and enables `fstrim.timer` when systemd provides it. Hardening configures UFW, fail2ban, managed sysctl protections, sticky `/tmp` and `/var/tmp`, conservative OpenSSH daemon guardrails, and Debian apt settings that reject insecure repositories. These steps are best-effort and continue on failure unless a required package install fails.

## Package Availability Test

Run the diagnostic checker when you want to find package name or repository discrepancies without installing anything:

```bash
./install_test.sh
./install_test.sh --profile wireless,netops
```

It reads [data/package-groups.yaml](data/package-groups.yaml), checks the current system's package manager, prints every package checked, and exits nonzero if any selected package is unavailable. On Arch, it checks pacman, installed yay, and the read-only AUR RPC. It does not install or enable anything.

## Git Defaults

The installer applies these target-user Git defaults:

```bash
git config --global init.defaultBranch main
git config --global pull.ff only
git config --global fetch.prune true
git config --global merge.conflictstyle zdiff3
git config --global rerere.enabled true
git config --global core.editor nvim
```

If `delta` is available, it is configured as the pager and interactive diff filter with navigation and side-by-side diffs.

## Optional Profiles

### Comfort

Installs CLI workflow helpers such as `atuin`, `zoxide`, `direnv`, `mise`, `just`, `watchexec`, `hyperfine`, `trash-cli`, `httpie`, `miller`, `ripgrep-all`, `yazi`, `zellij`, `lazygit`, `difftastic`, `shellcheck`, `shfmt`, `gitleaks`, `age`, `sops`, `chezmoi`, and `etckeeper` where available.

The installer uses distro packages first. If selected tools are missing and `cargo` or `pipx` is available, it attempts user-level fallback installs for common Rust/Python tools. Cargo source-build fallbacks are enabled by default; set `LINUX_CLI_ENABLE_CARGO_FALLBACKS=0` to skip them. Debian/Ubuntu comfort installs include source-build prerequisites such as `build-essential`, `pkg-config`, and `libssl-dev` so cargo fallbacks can compile crates that need OpenSSL headers. On distro Rust toolchains that are older than current crate releases require, the installer uses compatible pinned cargo versions for affected tools. It keeps Tide as the Fish prompt and adds Fish functions for `mkcd`, `extract`, `dnscheck`, `certcheck`, `serve`, `jfu`, and `scs`.

The installer also creates a managed SSH include file at `~/.ssh/conf.d/00-defaults.conf` and adds `Include ~/.ssh/conf.d/*.conf` to `~/.ssh/config` when needed. It does not overwrite the user's full SSH config.

### Netops

Installs DNS tools, IP/ping tools, trace tools, packet capture, port scanning, TLS/SSL testing, bandwidth and latency testing, interface tools, open-port/process tools, WHOIS, Netcat/socket tools, ARP discovery, SMB testing, `mosh`, `sshfs`, `rclone`, and `rkhunter`. `rsync` is part of core, and SSH brute-force protection is configured by the core fail2ban install.

| Purpose | Arch | Debian / Ubuntu |
| --- | --- | --- |
| DNS tools | `bind` | `bind9-dnsutils` |
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
| Rootkit scanner | `rkhunter` | `rkhunter` |

### Storage

Installs filesystem administration, removable-media, SMB/CIFS, encryption, copy progress, recovery, and flash-media verification tools.

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

### Wireless

Installs NetworkManager CLI tooling, WPA backends, Wi-Fi scanning tools, firmware packages, RF-kill controls, mobile broadband support, and optional tray integration packages where available.

Selecting `wireless` adds Fish abbreviations such as `wifi`, `wifiscan`, `nmstat`, `nmt`, and `rfk`, plus `wifi-connect` and `wifi-info` functions. The script does not enable `iwd.service` automatically.

NetworkManager is enabled only when it is already active/enabled, no obvious existing network stack is detected, or `LINUX_CLI_ENABLE_NETWORKMANAGER=1` is set. Set `LINUX_CLI_ENABLE_NETWORKMANAGER=0` to skip service enablement.

### Diagnostics

Installs hardware listing tools, sensor tools, SMART/NVMe tools, partition tools, I/O monitoring, network usage tools, process tracing, and file/process debugging tools.

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

Installs Python, pip/pipx, virtual environment support, uv, build tools, CMake, pkg-config/pkgconf, and Neovim. It also installs or upgrades these pipx tools for the target user:

| Purpose | Arch | Debian / Ubuntu |
| --- | --- | --- |
| Python | `python`, `python-pip`, `python-pipx` | `python3`, `python3-pip`, `python3-venv`, `pipx` |
| Fast env/package tool | `uv` | installed with `pipx` when apt lacks it |
| Build tools | `base-devel`, `cmake`, `pkgconf` | `build-essential`, `cmake`, `pkg-config` |
| Editor | `neovim` | `neovim` |

```bash
ruff
black
pytest
pre-commit
```

### Docker

Docker is opt-in only:

```bash
sudo ./install.sh --profile docker
```

On Arch, the profile installs `docker`, `docker-compose`, `lazydocker`, `dive`, `ctop`, and `hadolint`, then enables Docker and adds the target user to the `docker` group.

On Debian/Ubuntu, the profile uses Docker's official apt repository by default and installs Docker Engine, CLI, containerd, Buildx, and the Compose plugin. To use distro packages instead, the fallback installs Debian's `docker.io` and `docker-compose` packages:

```bash
sudo LINUX_CLI_DOCKER_APT_SOURCE=distro ./install.sh --profile docker
```

The Fish config adds Docker aliases, but the scripts never run destructive Docker prune or cleanup commands automatically.

### Distro Helpers

Arch systems also get `pacman-contrib`, `reflector`, `pkgfile`, and `base-devel`; `paccache.timer` is enabled and `pkgfile -u` is run when available.

Debian/Ubuntu systems also get `apt-file`, `needrestart`, `debian-goodies`, `apt-transport-https`, `unattended-upgrades`, and `nala` where available.

## Refresh

After linux-cli-setup is installed, run `install.sh` again without profile options to refresh packages, managed Fish config, Fisher plugins, Tide settings, and MOTD for the saved profiles:

```bash
sudo ./install.sh
```

It reads the current package map and installs any missing packages from the saved profiles. You can also specify profiles to add or refresh:

```bash
sudo ./install.sh --profile dev,docker
```

`update.sh` remains as a compatibility wrapper to `install.sh`, but new automation should call `install.sh`.

Install and refresh runs create a log under `/var/log/linux-cli-setup/`. Package-manager output is hidden by default; the console shows each item being installed or updated. If a required step fails, the scripts show the error plus the last captured output for that item and roll back managed changes from that run. Package-manager system upgrades cannot be fully reversed by any shell script, but project-managed files, shell changes, and packages installed by the current run are rolled back where possible.

## Uninstall

Remove linux-cli-setup managed Fish and MOTD files:

```bash
sudo ./uninstall.sh
```

The default uninstall preserves installed packages and restores the saved pre-install shell when state is available. Package removal is explicit because many CLI packages may predate linux-cli-setup or be used by other workflows. Without a `--profile` selection, `--remove-packages` removes packages from all profiles saved by install, including `core`:

```bash
sudo ./uninstall.sh --remove-packages
sudo ./uninstall.sh --remove-packages --profile docker
```

Uninstall also logs to `/var/log/linux-cli-setup/`. It keeps going after individual errors and reports each item being removed.

Uninstall removes managed files, restores the saved shell, re-enables disabled MOTD snippets, and removes the default automatic update config. If the automatic update config was edited, uninstall backs it up instead of deleting it because it may contain local Pushover settings. Exact reversal of package-manager upgrades, firewall state, time settings, service enablement, and packages that existed before linux-cli-setup is not guaranteed.

## Time And NTP

The installer sets the system timezone to `America/Detroit` and configures chrony for automatic NTP synchronization. Managed NetworkManager and dhclient hooks pass DHCP-provided NTP servers into chrony, and `us.pool.ntp.org` is configured as the public fallback pool. A managed tmpfiles entry recreates chrony's DHCP source directory after reboot. The installer disables the legacy `systemd-timesyncd` service and removes the Debian/Ubuntu `systemd-timesyncd` package when present.

Core also enables fail2ban with an SSH jail that reads from the systemd journal and bans through UFW. A managed logrotate policy rotates `/var/log/linux-cli-setup/*.log` weekly.

Status and utility commands are installed into `/usr/local/bin`:

```bash
time-status
ntp-status
timecheck
ntpcheck
aliases
drivecheck
dockercheck
```

The `aliases` command prints the Fish abbreviations and aliases visible to the current user. `timecheck` shows chrony and NTP source details, and `ntpcheck` is installed as an alias to it.

## Automatic Updates

The installer adds `/usr/local/bin/auto-update` for unattended Debian/Ubuntu and Arch updates. It installs `/etc/auto-update.conf` as a root-only config file for local settings and Pushover credentials.

Real Pushover keys should be placed in that config file after install:

```bash
sudoedit /etc/auto-update.conf
```

Do not commit real Pushover keys to this repository. The installed auto-update script uses Pushover through HTTPS with `curl`; no secrets are embedded in the repo.

For local testing before install, use the ignored root `.auto-update.conf`. It is intentionally excluded from Git; the real runtime config belongs in `/etc/auto-update.conf`.

On systemd hosts, the installer enables `linux-cli-auto-update.timer`. It runs daily between 3:30 AM and 4:30 AM, giving systems with the same setup a randomized update window around 4 AM. If systemd is unavailable, the installer falls back to `/etc/cron.d/linux-cli-auto-update`.

## MOTD Behavior

On systems with `/etc/update-motd.d`, the installer adds `50-linux-cli-setup` and disables other executable MOTD snippets so the login view stays clean. To keep existing distro MOTD snippets enabled, run:

```bash
sudo LINUX_CLI_KEEP_DEFAULT_MOTD=1 ./install.sh
```

On systems without `/etc/update-motd.d`, the installer adds a Fish login hook under `/etc/fish/conf.d/`.

## Notes

Existing Fish config files are backed up with a `.linux-cli-setup.<timestamp>.bak` suffix before replacement. Open a new login session after installation so the default shell, Docker group membership, and MOTD changes apply.
