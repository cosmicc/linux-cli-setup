# Show the dynamic MOTD on Fish login shells when update-motd is unavailable.

if status is-login; and status is-interactive
    if command -q linux-cli-motd
        linux-cli-motd
    end
end
