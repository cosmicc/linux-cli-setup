# Fish configuration installed by linux-cli-setup.

set -g fish_greeting

if status is-interactive
    fish_default_key_bindings

    if command -q eza
        abbr --query ll; or abbr --add ll 'eza -lah --group-directories-first --icons=auto'
        abbr --query la; or abbr --add la 'eza -a --group-directories-first --icons=auto'
        abbr --query lt; or abbr --add lt 'eza --tree --level=2 --icons=auto'
    else
        abbr --query ll; or abbr --add ll 'ls -lah'
        abbr --query la; or abbr --add la 'ls -A'
    end

    abbr --query gs; or abbr --add gs 'git status --short'
    abbr --query gl; or abbr --add gl 'git log --oneline --decorate --graph --all'
    abbr --query gp; or abbr --add gp 'git pull --ff-only'

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
        abbr --query dlog; or abbr --add dlog 'docker logs --tail=100 -f'
        abbr --query dimages; or abbr --add dimages 'docker images'
        abbr --query dvolumes; or abbr --add dvolumes 'docker volume ls'
        abbr --query dnetworks; or abbr --add dnetworks 'docker network ls'
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
