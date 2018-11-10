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

bold=$(tput bold)
normal=$(tput sgr0)

AnalProbe='2e+16'

THREADS=$((`nproc` * 3 / 4))

USAGE="Usage:
\t${0##*/} [-d|-D|-g|-G] [-t][-c][-a|-f] [-T <arg>] <video file[s]>

${bold}-d${normal}
    Move original file to the trash after transcoding.
${bold}-D${normal}
    Imediately delete the original file after transcoding
${bold}-g${normal}
    Group the original file in a directory named 'Converted'.
    (The directory is created in the same directory of the original file.)
${bold}-G${normal}
    Group the original file in a directory named 'Converted'.
    (The directory is created in the current working directory.)

NOTE:
    If more than one of the above options is specified,
    only the last one will apply.


${bold}-t${normal}
    Touch the original file after transcoding.
${bold}-c${normal}
    Permit video stream copying, rather than transcoding.
    (This only applies to inputs with h264 or h265 encoding.)
${bold}-f${normal}
    Force transcoding audio track regardless of input codec
${bold}-a${normal}
    Force transcoding audio track regardless of input codec (same as '-f')

${bold}-T${normal} <arg>
    Transpose the frame; passed directly to FFmpeg. Options are:
    -- 0, 4, cclock_flip
        - Rotate by 90 degrees counterclockwise & vertically flip
    -- 1, 5, clock
        - Rotate by 90 degrees clockwise
    -- 2, 6, cclock
        - Rotate by 90 degrees counterclockwise,
    -- 3, 7, clock_flip
        - Rotate by 90 degrees clockwise & vertically flip
    NOTE:
        Overrides video-stream copying.

${bold}--preset${normal} <arg>
    Transcoding preset; passed directly to FFmpeg.
    Options are:
        ultrafast, superfast, veryfast, faster, fast,
        medium, slow (default), slower, veryslow
    NOTE:
        Overrides video-stream copying.

${bold}--tune${normal} <arg>
    Optimize settings for input type; passed directly to FFmpeg.
    Options are:
        film, animation, grain, stillimage, fastdecode, zerolatency
    NOTE:
        Overrides video-stream copying.
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


# Checks if element "$1" is in array "$2"
# @NOTE:
#   Be sure that array is passed in the form:
#       "${ARR[@]}"
elementIn () {
    shopt -s nocasematch
    local e
    for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
    return 1
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


PRESET=''
TUNE=''
TPOSE=''
TPOSE_LIST=({0..7} {,c}clock{,_flip})

optspec=":dDgGctT:fa-:"

while getopts "$optspec" opt
do
    case "${opt}" in
        d)  TRASH=true; MOVE=true;
            DELETE=false; GROUP=false; GROUP_HERE=false;
            ;;
        D)  DELETE=true; MOVE=true;
            TRASH=false; GROUP=false; GROUP_HERE=false;
            ;;
        g)  GROUP=true; MOVE=true;
            TRASH=false; DELETE=false; GROUP_HERE=false;
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

        T)  TPOSE="${OPTARG}"
            ;;
        -)
            case "${OPTARG}" in
                preset)
                    PRESET="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                tune)
                    TUNE="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;
        *)  if [ "$OPTERR" != 1 ] || [ "${optspec:0:1}" = ":" ]; then
                echo "Un-imlemented option chosen"
                echo "Try '$0 -h' for usage details."
                exit
            fi;;

    esac
done

shift $((OPTIND-1))

if [[ "${PRESET}${TUNE}${TPOSE}" ]] && [[ "$COPY_VID" = true ]]; then
    echo -e "\n${bold}WARNING:${normal}" >&2;
    echo -e "\tVideo-stream copying overridden.\n" >&2;
    COPY_VID=false
fi

[[ -z "$PRESET" ]] && PRESET='slow'

PreTune="-preset $PRESET"
[[ "$TUNE" ]] && PreTune="${PreTune} -tune $TUNE"

TPOSE_CMD=''

if [[ "$TPOSE" ]]; then
    if ! elementIn "$TPOSE" "${TPOSE_LIST[@]}"; then
        echo -e 'ERROR!!\nTranspose argument is not valid'
        echo -e "$USAGE"
        exit -1
    fi

    TPOSE_CMD=(-vf "transpose=${TPOSE}")
fi


INPUT=( "$@" )


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
        command ffmpeg -threads $THREADS                                \
                    -analyzeduration $AnalProbe -probesize $AnalProbe   \
                    -i "$f" -id3v2_version 3 -strict -2                 \
                    -max_muxing_queue_size 10240 ${PreTune}             \
                    -c:v "$v_codec" -c:a "$a_codec" ${TPOSE_CMD[@]}     \
                    "$f_264"

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
