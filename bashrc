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

# Converts a string to title-case
title_case() {
    echo "$*" | awk 'BEGIN{
        split("a the to at in on with and but or",w);
        for(i in w)
            nocap[w[i]]
        }
        function cap(word){
            return toupper(substr(word,1,1)) tolower(substr(word,2))
        }
        {
            for(i=1;i<=NF;++i){
                printf "%s%s",(i==1||i==NF||!(tolower($i) in nocap)?cap($i):tolower($i)),(i==NF?"\n":" ")
            }
        }'
}

# Removes leading and trailing whitespace
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

# Checks if element "$1" is in array "$2"
# @NOTE:
#   Be sure that array is passed in the form:
#       "${ARR[@]}"
#   e.g. 
#       if elementIn "$val" "${ARR[@]}"; then
elementIn () {
    local e
    for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
    return 1
}

alias today='date +%F'

