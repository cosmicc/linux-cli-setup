function wifi-connect --description 'Connect to a Wi-Fi network with nmcli'
    if test (count $argv) -lt 1
        echo "Usage: wifi-connect SSID"
        return 1
    end

    if not command -q nmcli
        echo "wifi-connect requires nmcli. Install the wireless profile for NetworkManager tools."
        return 1
    end

    set ssid $argv[1]
    read --silent --prompt-str "Wi-Fi password for $ssid: " password
    echo

    nmcli dev wifi connect "$ssid" password "$password"
end
