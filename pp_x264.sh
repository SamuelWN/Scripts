#!/bin/bash

set -euo pipefail

TRASH=false
DELETE=false
GROUP=false
GROUP_HERE=false
MOVE=false
TOUCH=false
COPY_VID=false
COPY_AUD=true

THREADS=$((`nproc` * 3 / 4))

USAGE="Usage:
\t${0##*/} [-d|-D|-g|-G] [-t][-c][-a|-f] <video file[s]>

-d
    Move original file to the trash after transcoding.
-D
    Imediately delete the original file after transcoding
-g
    Group the original file in a directory named 'Converted'.
    (The directory is created in the same directory of the original file.)
-G
    Group the original file in a directory named 'Converted'.
    (The directory is created in the current working directory.)

NOTE:
    If more than one of the above options is specified,
    only the last one will apply.


-t
    Touch the original file after transcoding.
-c
    Permit video stream copying, rather than transcoding.
    (This only applies to inputs with h264 or h265 encoding.)
-f
    Force transcoding audio track regardless of input codec
-a
    Force transcoding audio track regardless of input codec (same as '-f')
"

vcodec() {
    mediainfo --Inform="Video;%Format%" "$1"
}
acodec() {
    # NewLine & head required to restrict to only analyze the default stream
    mediainfo --Inform="Audio;%Format%\n" "$1" | head -n1
}

cleanup() {
    echo 'Something went wrong during the transcoding process...' >&2;
    echo "'$f_264' will be moved to the trash." >&2;
    rm "$f_264" && exit 255;
}

globGet() {
    for f in "$1"; do
        if [[ -e "$f" ]]; then
            echo "$f"
        else
            return 1
        fi
    done
}


autoincr() {
    f="$1"
    ext="${f##*.}"

    if [[ -e "$f" ]] ; then
        i=1
        let substr_len=255
        f="${f%.*}";

        # Substring in case of long filenames
        while [[ -e "${f:0:substr_len}_${i}.${ext}" ]] ; do
            let substr_len=$((255-(2 + ${#i} + ${#ext}) ))
            let i++
        done

        f="${f}_${i}.${ext}"
    fi
    echo "$f"
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo -e "$USAGE"
    exit 0;
fi

while getopts ":dDgGctfa" opt
do
    case $opt in
        d)  TRASH=true; MOVE=true;
            DELETE=false; GROUP=false; GROUP_HERE=false;
            ;;
        D)  DELETE=true; MOVE=true;
            TRASH=false; GROUP=false; GROUP_HERE=false;
            ;;
        g)  GROUP=true; MOVE=true;
            TRASH=false; DELETE=false;GROUP_HERE=false;
            ;;
        G)  GROUP_HERE=true; MOVE=true;
            TRASH=false; DELETE=false; GROUP=false;
            ;;
        t)  TOUCH=true;
            ;;
        c)  COPY_VID=true;
            ;;
      f|a)  COPY_AUD=false;
            ;;
        *)  echo "Un-imlemented option chosen"
            echo "Try '$0 -h' for usage details."
            exit;;
    esac
done

shift $((OPTIND-1))


INPUT=( "$@" )

# Check to see if a pipe exists on stdin.
if [ -p /dev/stdin ]; then
    while IFS= read line; do
        INPUT=( "${INPUT[@]}" "${line}" )
    done
fi

if [[ "${#INPUT[@]}" == 0 ]]; then
    # Prints usage if no files provided
    echo -e "$USAGE"
    exit -1;
fi


for f in "${INPUT[@]}"; do
    [[ ! -f "$f" ]] && echo -e "$USAGE" && exit 1;

    f_264="${f%.*}";
    # Substring in case of long filenames
    [[ "${f##*.}" == "mp4" ]] && f_264="${f_264:0:246}_x264"
    f_264="$(autoincr "${f_264}.mp4")"

    v_codec="libx264"
    if [[ "$COPY_VID" = true ]]; then
        [[ $(vcodec "$f") == "AVC" ]] || [[ $(vcodec "$f") == "HEVC" ]] && \
            v_codec="copy";
    fi

    a_codec="aac"
    if [[ "$COPY_AUD" = true ]]; then
        [[ "$(acodec "$f")" == "AAC" ]] || [[ "$(acodec "$f")" == "AC-3" ]] && \
            a_codec="copy";
    fi

    {
        command ffmpeg -threads $THREADS -i "$f" -preset slow -id3v2_version 3 \
                -tune film -strict -2 -max_muxing_queue_size 4096 \
                -c:v "$v_codec" -c:a "$a_codec" "$f_264"

        # Check FFmpeg exit code:
        [[  $? -ne 0  ]] && cleanup

        if [[ "$(mediainfo --Inform="General;%Cover%" "$f")" == "Yes" ]]; then
            AtomicParsley "$f" -E && \
            g="${f%.*}" && g="${g:0:200}" && \
            cover="$(globGet "${g}"*"_artwork_"*".jpg")" && \
            AtomicParsley "$f_264" --artwork "$cover" --overWrite && \
            rm ./"$cover"
        fi
    } || {
        cleanup
    }

    if [[ "$TRASH" = true ]]; then
        gvfs-trash "$f"
    elif [[ "$DELETE" = true ]]; then
        rm "$f"
    elif [[ "$GROUP" = true ]]; then
        verted="$(dirname "$f")/Converted";
        [[ -d "$verted" ]] || mkdir "$verted";
        mv --backup=numbered "$f" "$verted";
    elif [[ "$GROUP_HERE" = true ]]; then
        verted="$PWD/Converted";
        [[ -d "$verted" ]] || mkdir "$verted";
        mv --backup=numbered "$f" "$verted";
    fi

    [[ "$MOVE" = true ]] && {
        [[ "${f_264%.*}" != "${f%.*}" ]] && mv "$f_264" "${f%.*}.mp4";
    }

    [[ "$TOUCH" = true ]] && {
        touch "$f"
    }
    echo -e "\nDone!"
done
