#!/bin/bash
# @author   Samuel Walters-Nevet                                                                                                                                                #
# @date     Summer, 2016                                                                                                                                                        #
# @brief    Batch converter of files to the HEVC codec via FFmpeg, using NVidia's 'hevc_nvenc' codec                                                                            #
# @file     pp_gpu.sh                                                                                                                                                           #
#                                                                                                                                                                               #
# Prerequisits:                                                                                                                                                                 #
#   ffmpeg with nvenc (see 'build_ffmpeg.sh')                                                                                                                                   #
#   mediainfo   (sudo apt install mediainfo)                                                                                                                                    #
#   AtomicParsely (sudo apt install atomicparsley)                                                                                                                              #
#                                                                                                                                                                               #
# Note:                                                                                                                                                                         #
#   The following function can be placed cut and pasted into your bashrc file ('~/.bashrc') to make calling this script easier:                                                 #
                                                                                                                                                                                #
ppg(){                                                                                                                                                                          #
    bash "$HOME/scripts/pp_gpu".sh "$@"                                                                                                                                         #
}                                                                                                                                                                               #
#                                                                                                                                                                               #
#################################################################################################################################################################################

set -euo pipefail
shopt -s extglob

TRASH=false
DELETE=false
GROUP=false
GROUP_HERE=false

USAGE="\tUsage: ppg [-d|-D|-g] <video file[s]>
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
"

cleanup() {
    echo 'Something went wrong during the transcoding process...' >&2;
    echo "'$f_265' will be moved to the trash." >&2;
    rm "$f_265" && exit 255;
}

autoincr() {
    f="$1"
    ext="${f##*.}"

    if [[ -e "$f" ]] ; then
        i=1
        f="${f%.*}";

        while [[ -e "${f}_${i}.${ext}" ]] ; do
            let i++
        done

        f="${f}_${i}.${ext}"
    fi
    echo "$f"
}

[[ "$1" == "--help" ]] && echo -e "$USAGE" && exit;

while getopts ":dDgGh" opt
do
    case $opt in
    d)  TRASH=true;;
    D)  DELETE=true;;
    g)  GROUP=true;;
    G)  GROUP_HERE=true;;
    h)  echo -e "$USAGE"; exit ;;
    *)  echo "Un-imlemented option chosen"
        echo "Try '$0 -h' for usage details."
        exit;;
    esac
done
shift $((OPTIND-1))

if [[ -z "$1" ]]; then
    # Prints usage if no files provided
    echo -e "$USAGE"
    exit -1;
fi


for f in "$@"; do
    [[ ! -f "$f" ]] && echo -e "$USAGE" && exit 1;

    f_265="${f%.*}";
    [[ "${f##*.}" == "mp4" ]] && f_265="${f_265}_nvenc"
    f_265="${f_265}.mp4";
    f_265="$(autoincr "$f_265")"

    a_codec="aac"
    [[ $(ffprobe "$f" 2>&1 | egrep "Audio: aac") ]] && a_codec="copy";
    {
        ffmpeg -threads 6 -i "$f" -y -preset slow -c:v hevc_nvenc -c:a "$a_codec" -id3v2_version 3 -metadata vcodec="hevc_nvenc" "$f_265" && \

        # Check FFmpeg exit code:
        [[  $? -ne 0  ]] && cleanup

        if [[ "$(mediainfo --Inform="General;%Cover%" "$f")" == "Yes" ]]; then
            cover="${f%.*}_artwork_1.jpg"
            AtomicParsley "$f" -E && \
            AtomicParsley "$f_265" --artwork "$cover" --overWrite && \
            rm ./"$cover"
        fi
    } || {
        cleanup
    }
    if [[ "$TRASH" = true ]]; then
        gvfs-trash "$f";
        [[ "${f_265%.*}" != "${f%.*}" ]] && mv "$f_265" "${f%.*}.mp4";
    elif [[ "$DELETE" = true ]]; then
        rm "$f"
        [[ "${f_265%.*}" != "${f%.*}" ]] && mv "$f_265" "${f%.*}.mp4";
    elif [[ "$GROUP" = true ]]; then
        verted="$(dirname "$f")/Converted";
        [[ -d "$verted" ]] || mkdir "$verted";
        mv --backup=numbered "$f" "$verted";

        [[ "${f_265%.*}" != "${f%.*}" ]] && mv "$f_265" "${f%.*}.mp4";
    elif [[ "$GROUP_HERE" = true ]]; then
        verted="$PWD/Converted";
        [[ -d "$verted" ]] || mkdir "$verted";
        mv --backup=numbered "$f" "$verted";

        [[ "${f_265%.*}" != "${f%.*}" ]] && mv "$f_265" "${f%.*}.mp4";
    fi && \
    echo -e "\nDone!"
done;
