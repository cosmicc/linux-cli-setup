function jfu --description 'Follow journal logs for one or more systemd units'
    if test (count $argv) -eq 0
        echo "Usage: jfu unit..."
        return 1
    end

    journalctl -fu $argv
end
