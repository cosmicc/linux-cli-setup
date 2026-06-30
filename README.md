# Linux CLI Setup

Group-based setup scripts for Arch-based and Debian/Ubuntu-based Linux systems. The default install is a safe `core` CLI baseline; heavier roles such as development, network troubleshooting, Docker hosting, and desktop helpers are optional package groups.

Current alpha testing version: `0.2a`.

## Supported Systems

- Arch-based systems with `pacman`; the installer also ensures `yay` is installed.
- Debian/Ubuntu-based systems with `apt`; scripts use `apt-get` even when `nala` is installed for interactive use.

## Quick Start

Run from the user account that should receive Fish as the default shell:

```bash
sudo ./install.sh
```

In an interactive terminal, install asks whether to add `dev`, `netops`, `docker`, and `desktop`. `core` is always installed and is not prompted. The script targets the sudoing user from `$SUDO_USER`, not `root`. If you must run as root directly, set the target user:

```bash
TARGET_USER=myuser ./install.sh
```

## Package Groups

`core` is always included. Add optional groups noninteractively with `--profile` or install every supported group with `--all-profiles`.

```bash
sudo ./install.sh --profile dev,netops
sudo ./install.sh --profile docker
sudo ./install.sh --all-profiles
```

Package names are read from [data/package-groups.tsv](data/package-groups.tsv). Edit that file to change which Arch or Debian/Ubuntu packages belong to each group.

Use `--debug` to show captured package-manager output in the console and log file. Use `--no-color` to disable colored console output.

Before install, update, or uninstall makes system changes, the script checks GitHub releases and prereleases for a newer `linux-cli-setup` version. If a newer version exists, it fetches and pulls from `origin/main` with Git progress shown, then restarts the same command from a temporary wrapper in `/tmp`. Set `LINUX_CLI_SKIP_SELF_UPDATE=1` only for troubleshooting when you intentionally need to run the local checkout as-is.

Show the script version:

```bash
./install.sh --version
./update.sh --version
./uninstall.sh --version
```

Available profiles:

| Profile | Purpose |
| --- | --- |
| `core` | Always-installed CLI baseline, Fish prompt, Git defaults, MOTD, and distro helpers. |
| `dev` | Python, C/C++ build tools, Neovim, uv, pipx tools, and developer Git helpers. |
| `netops` | DNS, packet capture, port scanning, VPN, SSH, transfer, and MSP troubleshooting tools. |
| `diagnostics` | Hardware, disk, sensor, I/O, network usage, tracing, and process diagnostics. Explicit-only for compatibility. |
| `docker` | Docker host packages, Compose plugin, Docker CLI helpers, and Fish Docker aliases. |
| `desktop` | GUI workstation clipboard, desktop integration, and notification helpers. |

## Core Install

The `core` profile installs OpenSSH, Git, Fish, htop, btop, JetBrainsMono Nerd Font Mono, Fisher, Tide, a screenshot-inspired Fish prompt, and a dynamic MOTD.

It also adds common CLI tools:

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
| Nerd Font package | `ttf-jetbrains-mono-nerd` | installed from Nerd Fonts release fallback |

Some recommended packages are installed best-effort because older distro releases may not ship every package.

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

### Netops

Installs DNS tools, IP/ping tools, trace tools, packet capture, port scanning, bandwidth testing, interface tools, open-port/process tools, WHOIS, Netcat/socket tools, ARP discovery, SMB testing, SNMP, VPN tools, `mosh`, `sshfs`, `rsync`, `rclone`, and `fail2ban`.

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

On Debian/Ubuntu, the profile uses Docker's official apt repository by default and installs Docker Engine, CLI, containerd, Buildx, and the Compose plugin. To use distro packages instead:

```bash
sudo LINUX_CLI_DOCKER_APT_SOURCE=distro ./install.sh --profile docker
```

The Fish config adds Docker aliases, but the scripts never run destructive Docker prune or cleanup commands automatically.

### Distro Helpers

Arch systems also get `pacman-contrib`, `reflector`, `pkgfile`, and `base-devel`; `paccache.timer` is enabled and `pkgfile -u` is run when available.

Debian/Ubuntu systems also get `apt-file`, `needrestart`, `debian-goodies`, `software-properties-common`, `apt-transport-https`, `unattended-upgrades`, and `nala` where available.

## Update

Refresh packages, managed Fish config, Fisher plugins, Tide settings, and MOTD:

```bash
sudo ./update.sh
```

If no group is given, `update.sh` uses the groups saved by the last install. It reads the current package map and installs any missing packages from those saved groups. You can also specify groups:

```bash
sudo ./update.sh --profile dev,docker
```

Install and update runs create a log under `/var/log/linux-cli-setup/`. Package-manager output is hidden by default; the console shows each item being installed or updated. If a required step fails, the scripts show the error plus the last captured output for that item and roll back managed changes from that run. Package-manager system upgrades cannot be fully reversed by any shell script, but project-managed files, shell changes, and packages installed by the current run are rolled back where possible.

## Uninstall

Remove linux-cli-setup managed Fish and MOTD files:

```bash
sudo ./uninstall.sh
```

The default uninstall preserves installed packages and restores the saved pre-install shell when state is available. Package removal is explicit. Without a `--profile` selection, `--remove-packages` removes the optional groups saved by install, but leaves all `core` packages installed:

```bash
sudo ./uninstall.sh --remove-packages
sudo ./uninstall.sh --remove-packages --profile docker
```

Uninstall also logs to `/var/log/linux-cli-setup/`. It keeps going after individual errors and reports each item being removed.

## Time And NTP

The installer sets the system timezone to `America/Detroit` and enables automatic NTP synchronization. On systemd systems, it configures `systemd-timesyncd` so DHCP-provided NTP servers remain preferred and `us.pool.ntp.org` is used as the fallback pool.

Two status commands are installed:

```bash
time-status
ntp-status
```

## Automatic Updates

The installer adds `/usr/local/sbin/linux-cli-auto-update` for unattended Debian/Ubuntu and Arch updates. It installs `/etc/linux-cli-setup/auto-update.conf` as a root-only config file for local settings and Pushover credentials.

Real Pushover keys should be placed in that config file after install:

```bash
sudoedit /etc/linux-cli-setup/auto-update.conf
```

Do not commit real Pushover keys to this repository. The installed auto-update script uses Pushover through HTTPS with `curl`; no secrets are embedded in the repo.

For local testing before install, use the ignored root `.auto-update.conf`. It is intentionally excluded from Git; the real runtime config still belongs in `/etc/linux-cli-setup/auto-update.conf`.

On systemd hosts, the installer enables `linux-cli-auto-update.timer`. It runs daily between 3:30 AM and 4:30 AM, giving systems with the same setup a randomized update window around 4 AM. If systemd is unavailable, the installer falls back to `/etc/cron.d/linux-cli-auto-update`.

## MOTD Behavior

On systems with `/etc/update-motd.d`, the installer adds `50-linux-cli-setup` and disables other executable MOTD snippets so the login view stays clean. To keep existing distro MOTD snippets enabled, run:

```bash
sudo LINUX_CLI_KEEP_DEFAULT_MOTD=1 ./install.sh
```

On systems without `/etc/update-motd.d`, the installer adds a Fish login hook under `/etc/fish/conf.d/`.

## Notes

Existing Fish config files are backed up with a `.linux-cli-setup.<timestamp>.bak` suffix before replacement. Open a new login session after installation so the default shell, Docker group membership, and MOTD changes apply.
