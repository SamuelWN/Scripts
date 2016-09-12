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


USAGE="\tUsage: ppg [-d|-D|-g] <video file[s]>\n"
TRASH=false
DELETE=false
GROUP=false

cleanup() {
    echo 'Something went wrong during the transcoding process...' >&2;
    echo "'$f_265' will be moved to the trash." >&2;
    rm "$f_265" && exit 255;
}

for opt in $@; do
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        # Prints usage if requested
        echo -e "$USAGE"
        exit 0;
    elif [[ "$1" = "-d" ]]; then
        TRASH=true;
        shift
    elif [[ "$1" = "-D" ]]; then
        DELETE=true;
        shift
    elif [[ "$1" = "-g" ]] || [[ "$1" = "-G" ]]; then
        GROUP=true;
        shift
    fi
done

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
