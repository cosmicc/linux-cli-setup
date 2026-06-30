function dnscheck --description 'Show common DNS records for a domain'
    set domain $argv[1]

    if test -z "$domain"
        echo "Usage: dnscheck domain.com"
        return 1
    end

    if not command -q dig
        echo "dnscheck requires dig. Install the netops profile for DNS tools."
        return 1
    end

    echo "A:"
    dig +short A "$domain"

    echo
    echo "AAAA:"
    dig +short AAAA "$domain"

    echo
    echo "MX:"
    dig +short MX "$domain"

    echo
    echo "TXT:"
    dig +short TXT "$domain"

    echo
    echo "NS:"
    dig +short NS "$domain"

    echo
    echo "SOA:"
    dig +short SOA "$domain"
end
