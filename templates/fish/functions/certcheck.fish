function certcheck --description 'Show TLS certificate details for a host'
    set host $argv[1]
    set port 443

    if test -n "$argv[2]"
        set port $argv[2]
    end

    if test -z "$host"
        echo "Usage: certcheck domain.com [port]"
        return 1
    end

    if not command -q openssl
        echo "certcheck requires openssl."
        return 1
    end

    echo | openssl s_client -servername "$host" -connect "$host:$port" 2>/dev/null \
        | openssl x509 -noout -subject -issuer -dates -fingerprint
end
