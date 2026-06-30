function serve --description 'Serve the current directory over HTTP'
    set port 8000

    if test -n "$argv[1]"
        set port $argv[1]
    end

    if command -q python3
        python3 -m http.server "$port"
    else if command -q python
        python -m http.server "$port"
    else
        echo "serve requires python3 or python."
        return 1
    end
end
