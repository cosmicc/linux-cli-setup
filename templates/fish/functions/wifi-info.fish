function wifi-info --description 'Show Wi-Fi and RF-kill status'
    if not command -q nmcli
        echo "wifi-info requires nmcli. Install the wireless profile for NetworkManager tools."
        return 1
    end

    echo "Devices:"
    nmcli dev status

    echo
    echo "Wi-Fi radio:"
    nmcli radio wifi

    echo
    echo "Known Wi-Fi connections:"
    nmcli -f NAME,TYPE,AUTOCONNECT connection show | grep wifi

    echo
    echo "RFKill:"
    if command -q rfkill
        rfkill list
    else
        echo "rfkill is not installed."
    end
end
