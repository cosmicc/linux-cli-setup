# >>> linux-cli-setup managed Fastfetch MOTD >>>
# Fastfetch system information on terminal startup
if status --is-interactive && type -q fastfetch
    fastfetch --config neofetch.jsonc
end
# <<< linux-cli-setup managed Fastfetch MOTD <<<
