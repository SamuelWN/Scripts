#!/bin/bash
# Batch transcoding of files to to the hevc codec

set -euo pipefail

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
    [[ "${f##*.}" == "mp4" ]] && f_265="${f_265}_x265"
    f_265="${f_265}.mp4";

    a_codec="aac"
    [[ $(ffprobe "$f" 2>&1 | egrep "Audio: aac") ]] && a_codec="copy";
    {
        ffmpeg -threads 6 -i "$f" -preset slow -c:v libx265 -c:a "$a_codec" "$f_265" && \
        if [[ "$(mediainfo --Inform="General;%Cover%" "$f")" == "Yes" ]]; then
            cover="${f%.*}_artwork_1.jpg"
            AtomicParsley "$f" -E && \
            AtomicParsley "$f_265" --artwork "$cover" --overWrite && \
            rm ./"$cover"
        fi
    } || {
        cleanup
    }
    if [[ "$TRASH" = true ]]; then gvfs-trash "$f"
    elif [[ "$DELETE" = true ]]; then rm "$f"
    elif [[ "$GROUP" = true ]]; then
        # verted="/media/samuelwn/RAID/ToDel/Converted";
        verted="$(dirname "$f")/Converted";
        [[ -d "$verted" ]] || mkdir "$verted";
        mv --backup=numbered "$f" "$verted"
    fi && \
    { [[ "$f_265" == "${f%.*}.mp4" ]] || mv "$f_265" "${f%.*}.mp4" ; } && \
    echo -e "\nDone!"
done
