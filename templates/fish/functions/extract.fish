function extract --description 'Extract common archive formats'
    if test (count $argv) -eq 0
        echo "Usage: extract archive..."
        return 1
    end

    for file in $argv
        if not test -f "$file"
            echo "Not a file: $file"
            continue
        end

        switch "$file"
            case '*.tar.bz2'
                tar xjf "$file"
            case '*.tar.gz' '*.tgz'
                tar xzf "$file"
            case '*.tar.xz'
                tar xJf "$file"
            case '*.tar'
                tar xf "$file"
            case '*.zip'
                unzip "$file"
            case '*.7z'
                7z x "$file"
            case '*.gz'
                gunzip "$file"
            case '*.bz2'
                bunzip2 "$file"
            case '*'
                echo "Unknown archive type: $file"
        end
    end
end
