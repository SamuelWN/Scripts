#!/bin/bash

# Extract archives:
function extract {
    if [[ -z "$1" ]]; then
        # display usage if no parameters given
        echo "Usage: extract <archive>"
    else
        IN_DIR=0

        if [[ "$1" = "-f" ]] || [[ "$1" = "-d" ]]; then
            IN_DIR=1;
            shift
        fi

        if [[ -f "$1" ]] ; then
            IN="$1"

            if [[ $IN_DIR -eq 1 ]]; then
                NAME="${1%.*}"
                mkdir "$NAME" && cd "$NAME"
                IN="../$1"
            fi

            case "$1" in
            *.tar.bz2) tar xvjf "$IN" ;;
            *.tar.gz) tar xvzf "$IN" ;;
            *.tar.xz) tar xvJf "$IN" ;;
            *.lzma) unlzma "$IN" ;;
            *.bz2) bunzip2 "$IN" ;;
            *.rar) unrar x -ad "$IN" ;;
            *.gz) gunzip "$IN" ;;
            *.tar) tar xvf "$IN" ;;
            *.tbz2) tar xvjf "$IN" ;;
            *.tgz) tar xvzf "$IN" ;;
            *.zip) unzip "$IN" ;;
            *.Z) uncompress "$IN" ;;
            *.7z) 7z x "$IN" ;;
            *.xz) unxz "$IN" ;;
            *.exe) cabextract "$IN" ;;
            *) echo "extract: '$1' - unknown archive method" ;;
            esac
        else
            echo "$1 - file does not exist"
        fi
    fi
}

# RTMPDump configuration
alias rtmp-pre="sudo iptables -t nat -A OUTPUT -p tcp --dport 1935 -j REDIRECT"
alias rtmp-post="sudo iptables -t nat -D OUTPUT -p tcp --dport 1935 -j REDIRECT"
alias rtmpsrv="rtmp-pre && rtmpsrv; rtmp-post"
alias rtmpsuck="rtmp-pre && rtmpsuck; rtmp-post"

# Obtain your public IP address
alias pubip='dig +short myip.opendns.com @resolver1.opendns.com'

# Auto-sudo `apt` command where needed
apt() {
    if  [[ "$1" == "search" ]] || [[ "$1" == "show" ]] || \
        [[ "$1" == "list" ]] || [[ "$1" == "help" ]]; then
        command apt $@
    else
        sudo apt $@
    fi
}
