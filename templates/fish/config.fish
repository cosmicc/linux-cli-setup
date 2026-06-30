# Fish configuration installed by linux-cli-setup.

set -g fish_greeting

if status is-interactive
    fish_default_key_bindings

    if test -d "$HOME/.local/bin"
        fish_add_path -g "$HOME/.local/bin"
    end

    if test -d "$HOME/.cargo/bin"
        fish_add_path -g "$HOME/.cargo/bin"
    end

    if command -q atuin
        atuin init fish | source
    end

    if command -q zoxide
        zoxide init fish | source
    end

    if command -q direnv
        direnv hook fish | source
    end

    if command -q mise
        mise activate fish | source
    end

    if command -q eza
        abbr --query ll; or abbr --add ll 'eza -lah --group-directories-first --icons=auto'
        abbr --query la; or abbr --add la 'eza -a --group-directories-first --icons=auto'
        abbr --query lt; or abbr --add lt 'eza --tree --level=2 --icons=auto'
    else
        abbr --query ll; or abbr --add ll 'ls -lah'
        abbr --query la; or abbr --add la 'ls -A'
    end

    abbr --query gs; or abbr --add gs 'git status -sb'
    abbr --query ga; or abbr --add ga 'git add'
    abbr --query gc; or abbr --add gc 'git commit'
    abbr --query gp; or abbr --add gp 'git push'
    abbr --query gpl; or abbr --add gpl 'git pull --ff-only'
    abbr --query gl; or abbr --add gl 'git log --oneline --graph --decorate --all'
    abbr --query gd; or abbr --add gd 'git diff'
    abbr --query gdc; or abbr --add gdc 'git diff --cached'

    if command -q bat
        abbr --query catp; or abbr --add catp 'bat --paging=never'
    else if command -q batcat
        abbr --query bat; or abbr --add bat batcat
        abbr --query catp; or abbr --add catp 'batcat --paging=never'
    end

    if not command -q fd; and command -q fdfind
        abbr --query fd; or abbr --add fd fdfind
    end

    if command -q docker
        abbr --query d; or abbr --add d docker
        abbr --query dc; or abbr --add dc 'docker compose'
        abbr --query dps; or abbr --add dps 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
        abbr --query dlog; or abbr --add dlog 'docker logs --tail=200 -f'
        abbr --query dcu; or abbr --add dcu 'docker compose up -d'
        abbr --query dcd; or abbr --add dcd 'docker compose down'
        abbr --query dcl; or abbr --add dcl 'docker compose logs -f --tail=200'
        abbr --query dimages; or abbr --add dimages 'docker images'
        abbr --query dvolumes; or abbr --add dvolumes 'docker volume ls'
        abbr --query dnetworks; or abbr --add dnetworks 'docker network ls'
    end

    if command -q nmcli
        abbr --query nmstat; or abbr --add nmstat 'nmcli dev status'
        abbr --query nmc; or abbr --add nmc 'nmcli connection show'
        abbr --query wifi; or abbr --add wifi 'nmcli dev wifi list'
        abbr --query wifiscan; or abbr --add wifiscan 'nmcli dev wifi rescan; nmcli dev wifi list'
        abbr --query wifiup; or abbr --add wifiup 'nmcli radio wifi on'
        abbr --query wifidown; or abbr --add wifidown 'nmcli radio wifi off'
        abbr --query nmreload; or abbr --add nmreload 'sudo systemctl restart NetworkManager'
        abbr --query nmlog; or abbr --add nmlog 'journalctl -u NetworkManager -b --no-pager'
    end

    if command -q nmtui
        abbr --query nmt; or abbr --add nmt nmtui
    end

    if command -q rfkill
        abbr --query rfk; or abbr --add rfk 'rfkill list'
    end

    abbr --query rm; or abbr --add rm 'rm -I --preserve-root'
    abbr --query ports; or abbr --add ports 'sudo ss -tulpn'
    abbr --query jxe; or abbr --add jxe 'journalctl -xeu'
    abbr --query scs; or abbr --add scs 'systemctl status --no-pager -l'

    if command -q trash-put
        abbr --query del; or abbr --add del 'trash-put'
    end

    function update-system --description 'Update the current pacman or apt based system'
        if command -q pacman
            sudo pacman -Syu
        else if command -q apt
            sudo apt update; and sudo apt upgrade
        else
            echo 'No supported package manager found.'
            return 1
        end
    end
end
