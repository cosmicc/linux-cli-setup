function scs --description 'Show detailed systemd unit status'
    if test (count $argv) -eq 0
        echo "Usage: scs unit..."
        return 1
    end

    systemctl status --no-pager -l $argv
end
