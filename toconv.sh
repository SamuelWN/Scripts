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
#                                                                                                                                                                               #
# Potential Issues:                                                                                                                                                             #
# -- Need to verify that regex `find` code for checking file-extensions actually works as intended                                                                              #
#    (I'm fairly confident that the `mp(e|g|4)` portion does not)                                                                                                               #
#                                                                                                                                                                               #
#################################################################################################################################################################################

BITRATE=false
FFBR=false
ARGS=""
RATE=2100000
CUTOFF=false
CODEC=true
SCRIPT=false
TCODE_SCRPT="$HOME/scripts/pp_nvenc.sh"
TCODE_CMD="pp_nvenc"
SIZE="+0"
BY_RATE=false
VERBOSE=false

USAGE="Usage:\t$(basename "$0") [-s <size>] [-c] [-b] [-r <bitrate>] [directory]
-h
    Display this message.
-s n[cwbkMG]
    File uses n units of space, rounding up.
    Prefixes + and - signify greater than and less than. e.g. \"-s +1G\"
    Check the documentaion for \`find\` for more information (argument '-size').
-b
    Only return results with bitrates greater than 2,100 kbps
-f
    Use 'ffprobe' to obtain the bitrate, rather than 'mediainfo'
    (rarely - but occasionally - mediainfo has been unreliable in this regard)
-r <rate>
    Only return results with bitrates greater than the given bitrate (in kbps)
-R
    Sort results by bitrate (decending)
    Default: filesize (decending)
-c
    Include HEVC encoded files in the results
-v
    Verbose
-L
    Output batch conversion script to a file (named 'ToConv.sh')
[directory]
    The directory (including subdirectorys) to search
        (defaults to the current working directory)
"

# @TODO:
"
-a
    Any additional argument(s) wished to be passed to the 'find'.
    Example:
        toconv -a '-iname \"*filename*\"'
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

ff_bitrate () {
    ffprobe -show_format "$f" 2> /dev/null | grep "bit_rate" | sed 's/.*bit_rate=\([0-9]\+\).*/\1/g';
}

autoincr() {
    f="$1"
    ext=""
    [[ "$f" == *.* ]] && ext=".${f##*.}"

    if [[ -e "$f" ]] ; then
        i=1
        f="${f%.*}";

        while [[ -e "${f}_${i}${ext}" ]]; do
            let i++
        done

        f="${f}_${i}${ext}"
    fi
    echo "$f"
}


while getopts ":s:cbfr:a:RLvh" opt
do
    case $opt in
    s)  SIZE=("$OPTARG");
        CUTOFF=true;;
    b)  BITRATE=true;;
    f)  FFBR=true;;
# @TODO
#   a)  ARGS="$OPTARG";;
    r)  case "$OPTARG" in
            ''|*[!0-9]*) echo "ERROR"
                echo "    Option '-r' requires a numeric argument." ;
                echo "    Use '-h' to see usage guidelines.";
                exit;;
            *) let RATE=OPTARG*1000;
                BITRATE=true;;
        esac;;
    R)  BY_RATE=true;;
    L)  SCRIPT=true;;
    c)  CODEC=false;;
    v)  VERBOSE=true;;
    h)  echo -e "$USAGE"; exit ;;
    *)  echo "Un-imlemented option chosen"
        echo "Try '$0 -h' for usage details."
        exit;;
    esac
done
shift $((OPTIND-1))

if [[ $RATE -lt 2100000 ]]; then
    TCODE_CMD="pp"
    TCODE_SCRPT="$HOME/scripts/pp.sh";
fi

BATCH=""

GET_FILES="find \"\$@\" -type f -regex '.*\.\(mpeg\|mkv\|ra?m\|avi\|mp\(g\|e\|4\)\|mov\|divx\|asf\|qt\|wmv\|m\dv\|rv\|vob\|asx\|ogm\|ogv\|webm\|flv\|ts\)'"
GET_FILES="$GET_FILES -size \$SIZE -not -path \"*Converted*\" -not -path \"*Extracted*\""

if [[ "$BY_RATE" = true ]]; then
    GET_FILES="$GET_FILES  -execdir bash -c \"printf \\\`"
    if [[ "$FFBR" = true ]]; then
        GET_FILES="$GET_FILES ffprobe -show_format \\\"{}\\\" 2> /dev/null | grep \"bit_rate\" | sed 's/.*bit_rate=\\([0-9]\+\\).*/\\1/g'"
    else
        GET_FILES="$GET_FILES mediainfo --Inform=\\\"Video;%BitRate%\\\" \\\"{}\\\""
    fi

    GET_FILES="$GET_FILES \\\`\" \\; -printf \$' %p\\n'"

else
    GET_FILES="$GET_FILES -printf $'%s %p\n'"
fi

[[ "$VERBOSE" = true ]] && { echo -e "GET_FILES:\n$GET_FILES\n"; }


while read f; do
    [[ "$VERBOSE" = true ]] && echo "f: $f"

    [[ $f ]] || continue

    # Note: Swap comment status on following two lines (and below) to examine every file rather than limit to common video file extensions
    # if [[ -f "$f" ]] && is_vid "$f" && [[ "$(vcodec "$f")" != "HEVC" || "$CODEC" = false ]] && [[ ! -f "${f%.*}_x265.mp4" ]] && [[ ! -f "${f%.*}_nvenc.mp4" ]] && [[ ! "$(dirname "$f" | egrep "/Converted")" ]];
    if [[ -f "$f" ]] && [[ "$(vcodec "$f")" != "HEVC" || "$CODEC" = false ]] && [[ ! -f "${f%.*}_x265.mp4" ]] && [[ ! -f "${f%.*}_nvenc.mp4" ]] && [[ ! "$(dirname "$f" | egrep "/Converted")" ]];
    then
        MEM=$(du -h "$f" | cut -f 1)
        [[ "$VERBOSE" = true ]] && { echo "MEM: $MEM"; }

        if [[ "$FFBR" = false ]]; then
            B_RATE="$(mediainfo --Inform="Video;%BitRate%" "$f")";
        else
            B_RATE="$(ff_bitrate "$f")";
        fi

        [[ "$VERBOSE" = true ]] && { echo "B_RATE: $B_RATE"; }

        if [[ "$BITRATE" = false ]] || [[ "$B_RATE" -gt $RATE ]]; then
            B_RATE="$(printf "%'.f\n" `expr $B_RATE / 1000`)"
            f="${f//"'"/"'\''"}"
            f="${f//"!"/"'\!'"}"
            BATCH="$BATCH '$f'"
            echo "${MEM}B ($B_RATE kbps)";
            echo "$TCODE_CMD -g '$f'";
            echo ;
        fi
    fi

# Note: Swap comment status on following two lines (and above) to search every file rather than limit to common video file extensions
# done <<< "$(find -type f -not -path "*Converted*" -not -path "*Extracted*" -printf $'%s %p\n' | sort -k1,1nr -k2,2r | cut -d ' ' --complement -f 1)"
done <<< "$(eval "$GET_FILES" | sort --parallel=6 -k1,1nr -k2,2r | cut -d ' ' --complement -f 1)"


if [[ "$BATCH" ]]; then
    echo -e "Batch:\nnohup bash $TCODE_SCRPT -g$BATCH > nohup.out &"

    [[ "$SCRIPT" = true ]] && echo "$TCODE_SCRPT -g$BATCH" > "$(autoincr ToConv.sh)"
fi

