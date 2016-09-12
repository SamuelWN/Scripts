#!/bin/bash
# @author   Samuel Walters-Nevet                                                                                                                                                #
# @date     Summer, 2016                                                                                                                                                        #
# @brief    list files worth transcoding with the NVENC codec                                                                                                                   #
# @file     toconv.sh                                                                                                                                                           #
#                                                                                                                                                                               #
# Description:                                                                                                                                                                  #
# This is a script which searches through a given directory for video files, listing their size and video bitrate. Results are listed in decending order by size.               #
# The usefulness of this comes from its parameter options. Allowing the user to determine what files, if any, could benefit from transcoding (saving disk space).               #
#                                                                                                                                                                               #
# Notes:                                                                                                                                                                        #
# -- The bitrate floor of the '-b' option is chosen due experience showing this to be the fairly consistent bitrate of videos encoded with Nvidia's NVENC codec for FFmpeg.     #
# -- By default, videos using the HEVC codec are excluded from results. This can be disabled using the '-c' option                                                              #
#                                                                                                                                                                               #
# Prerequisits:                                                                                                                                                                 #
#   mediainfo   (sudo apt install mediainfo)                                                                                                                                    #
#################################################################################################################################################################################

SELF="$(basename "$0")"
BITRATE=false
CUTOFF=false
CODEC=true
SIZE=""
USAGE="Usage:\t${SELF} [-s] [-c] [-b]  [directory]
-s M|G|T|E|P|Y|Z
    Minimum file size for results
-b
    Only return results with bitrates greater than 2,000 kbps
-c
    Include HEVC encoded files in the results
[directory]
    The directory (including subdirectorys) to search
        (defaults to the current working directory)
"


vcodec() {
    mediainfo --Inform="Video;%Format%" "$1"
}
acodec() {
    mediainfo --Inform="Audio;%Format%" "$1"
}

is_vid() {
    [[ $(vcodec "$1") ]] && [[ $(acodec "$1") ]] && return 0;
    return 1;
}

while getopts ":s:cbh" opt
do
    case $opt in
    s)  SIZE="$OPTARG"; CUTOFF=true;;
    b)  BITRATE=true;;
    c)  CODEC=false;;
    h)  echo -e "$USAGE"; exit ;;
    *)  echo "Un-imlemented option chosen"
        echo "Try '$0 -h' for usage details."
        exit;;
    esac
done
shift $((OPTIND-1))


if [[ "$CUTOFF" = true ]] && [[ -z $SIZE || ${#SIZE} -ne 1 || ! "MGTEPYZ" =~ .*$SIZE.* ]]; then
    echo -e "$USAGE"
    exit -1;
fi


DIRS="."
if [[ $# > 0 ]]; then
    DIRS="$@"
fi

BATCH=""

while read f; do
    [[ $f ]] || continue

    # Note: Swap comment status on following two lines (and below) to search every file rather than limit to common video file extensions
    # if [[ -f "$f" ]] && is_vid "$f" && [[ "$(vcodec "$f")" != "HEVC" || "$CODEC" = false ]] && [[ ! -f "${f%.*}_x265.mp4" ]] && [[ ! -f "${f%.*}_nvenc.mp4" ]] && [[ ! "$(dirname "$f" | egrep "/Converted")" ]]; then
    if [[ -f "$f" ]] && [[ "$(vcodec "$f")" != "HEVC" || "$CODEC" = false ]] && [[ ! -f "${f%.*}_x265.mp4" ]] && [[ ! -f "${f%.*}_nvenc.mp4" ]] && [[ ! "$(dirname "$f" | egrep "/Converted")" ]]; then
        MEM=$(du -S "$f" | cut -f 1)
        MEM=$(echo $MEM | awk '
            function human(x) {
                if (x<1000) {return x} else {x/=1024}
                s="MGTEPYZ";
                while (x>=1000 && length(s)>1)
                    {x/=1024; s=substr(s,2)}
                return int(x+0.5) substr(s,1,1)
            }
            {sub(/^[0-9]+/, human($1)); print}'
        )
        if [[ "$CUTOFF" = false ]] || [[ $(echo ${MEM} | grep $SIZE) ]]; then
            B_RATE="$(mediainfo --Inform="Video;%BitRate%" "$f")"
            if [[ "$BITRATE" = false ]] || [[ "$B_RATE" -gt 2000000 ]]; then
                B_RATE="$(printf "%'.f\n" `expr $B_RATE / 1000`)"
                BATCH="$BATCH \"$f\""
                echo "${MEM}B ($B_RATE kbps)"
                echo "ppg -g \"$f\"";
                echo
            fi
        fi
    fi

# Note: Swap comment status on following two lines (and above) to search every file rather than limit to common video file extensions
# done <<< "$(find -type f -not -path "*Converted*" -not -path "*Extracted*" -printf $'%s %p\n' | sort -k1,1nr -k2,2r | cut -d ' ' --complement -f 1)"
done <<< "$(find  $DIRS -type f -regex '.*\.\(mpeg\|ra?m\|avi\|mp\(g\|e\|4\)\|mov\|divx\|asf\|qt\|wmv\|m\dv\|rv\|vob\|asx\|ogm\|ogv\|webm\|flv\|ts\)' -not -path "*Converted*" -not -path "*Extracted*" -printf $'%s %p\n' | sort -k1,1nr -k2,2r | cut -d ' ' --complement -f 1)"

if [[ "$BATCH" ]]; then
    echo -e "Batch:\nnohup $HOME/scripts/pp_gpu.sh -g $BATCH > nohup.out &"
fi

