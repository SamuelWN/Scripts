#!/bin/bash
# @author   Samuel Walters-Nevet                                                                                                                                                #
# @date     Summer, 2016                                                                                                                                                        #
# @brief    Batch converter of files to the HEVC codec via FFmpeg, using NVidia's 'hevc_nvenc' codec                                                                            #
# @file     pp_gpu.sh                                                                                                                                                           #
#                                                                                                                                                                               #
# Prerequisits:                                                                                                                                                                 #
#   ffmpeg with nvenc (see 'build_ffmpeg.sh')                                                                                                                                   #
#                                                                                                                                                                               #
# Note:                                                                                                                                                                         #
#   The following function can be placed cut and pasted into your bashrc file ('~/.bashrc') to make calling this script easier:                                                 #
                                                                                                                                                                                #
ppg(){                                                                                                                                                                          #
    bash "$HOME/scripts/pp_gpu".sh "$@"                                                                                                                                         #
}                                                                                                                                                                               #
#                                                                                                                                                                               #
#################################################################################################################################################################################


TRASH=false
DELETE=false
GROUP=false
USAGE="Usage: ppg [-d|-D|-g] <video file[s]>
-d
    Move original file to the trash after transcoding.
-D
    Imediately delete the original file after transcoding
-g
    Group the original file in a directory named 'Converted'.
    (The directory is created in the same directory of the original file.)
"

cleanup() {
    echo 'Something went wrong during the transcoding process...' >&2;
    echo "'$f_265' will be moved to the trash." >&2;
    rm "$f_265" && exit 255;
}

while getopts ":dDgh" opt
do
    case $opt in
    d)  TRASH=true;;
    D)  DELETE=true;;
    g)  GROUP=true;;
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

    a_codec="aac"
    [[ $(ffprobe "$f" 2>&1 | egrep "Audio: aac") ]] && a_codec="copy";
    {
        ffmpeg -threads 6 -i "$f" -preset slow -c copy -c:v hevc_nvenc -c:a "$a_codec" "$f_265"
    } || {
        cleanup
    }
    if [[ "$TRASH" = true ]]; then gvfs-trash "$f" && mv "$f_265" "${f%.*}.mp4";
    elif [[ "$DELETE" = true ]]; then rm "$f" && mv "$f_265" "${f%.*}.mp4";
    elif [[ "$GROUP" = true ]]; then
        verted="$(dirname "$f")/Converted";
        [[ -d "$verted" ]] || mkdir "$verted";
        mv --backup=numbered "$f" "$verted" && [[ "${f_265%.*}" != "${f%.*}" ]] && mv --backup=numbered "$f_265" "${f%.*}.mp4"
    fi && \
    echo -e "\nDone!"
done;
