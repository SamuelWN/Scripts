#!/bin/bash
# @author   Samuel Walters-Nevet                                                                                                                                                #
# @date     2016-2017                                                                                                                                                           #
# @brief    Batch converter of files to H264 codec via FFmpeg, using NVidia's 'h264_nvenc' codec                                                                                #
# @file     pp_nenv.sh                                                                                                                                                          #
#                                                                                                                                                                               #
# Prerequisits:                                                                                                                                                                 #
#   ffmpeg with nvenc (see 'build_ffmpeg.sh')                                                                                                                                   #
#   mediainfo   (sudo apt install mediainfo)                                                                                                                                    #
#   AtomicParsely (sudo apt install atomicparsley)                                                                                                                              #
#                                                                                                                                                                               #
# Note:                                                                                                                                                                         #
#   The following function can be placed cut and pasted into your bashrc file ('~/.bashrc') to make calling this script easier:                                                 #
ppn(){                                                                                                                                                                          #
    bash "$HOME/scripts/pp_nvenc".sh "$@"                                                                                                                                       #
}                                                                                                                                                                               #
#                                                                                                                                                                               #
#################################################################################################################################################################################

TRASH=false
DELETE=false
GROUP=false
GROUP_HERE=false;

USAGE="\tUsage: $(basename $0) [-d|-D|-g|-G] <video file[s]>
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
    rm "$f_265" && exit $1;
}

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

    a_codec="aac"
    [[ $(ffprobe "$f" 2>&1 | egrep "Audio: aac") ]] && a_codec="copy";
    {
        ffmpeg -threads 6 -i "$f" -preset slow -c:v h264_nvenc -c:a "$a_codec" "$f_265"

        # Check FFmpeg exit code:
        FFexit=$?
        [[  $FFexit -ne 0  ]] && cleanup $FFexit

        if [[ "$(mediainfo --Inform="General;%Cover%" "$f")" == "Yes" ]]; then
            cover="${f%.*}_artwork_1.jpg"
            AtomicParsley "$f" -E && \
            AtomicParsley "$f_265" --artwork "$cover" --overWrite && \
            rm ./"$cover"
        fi
    } || {
        cleanup 1
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
