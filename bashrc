#!/bin/bash

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

# Find duplicate files and replace them with hardlinks (requires rdfind)
lndupes() {
    DIR="$PWD"

    [[ $# > 0 ]] && DIR="$1";

    rdfind -makehardlinks true -ignoreempty true -outputname "$PWD/DuplicateFiles.txt" "$DIR/"*
}
