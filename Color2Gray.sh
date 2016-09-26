#!/bin/bash
# @author   Samuel Walters-Nevet                                                                                                #
# @date     Summer, 2016                                                                                                        #
# @brief    Batch converter pictures from color to grayscale, preserving folder structure                                       #
# @file     Color2Gray.sh                                                                                                       #
#                                                                                                                               #
# Prerequisits:                                                                                                                 #
#   ImageMagick (sudo apt install imagemagick)                                                                                  #
#                                                                                                                               #
#################################################################################################################################




COLOR=""
GRAY=""

while getopts ":i:o:" opt
do
    case $opt in
    i)  COLOR="$OPTARG";;
    o)  GRAY="$OPTARG";;
    *)  echo "Un-imlemented option chosen"
        exit;;
    esac
done

[[ -z "$COLOR" ]] && COLOR="$PWD"

[[ -z "$GRAY" ]] && GRAY="$(dirname "$COLOR")/Gray"
[[ ! -d "$GRAY" ]] && mkdir "$GRAY"

for f in "$COLOR"/*; do

    if [[ -d "$f" ]]; then
       NEW_DIR="$GRAY/${f##*"$COLOR"}"
       [[ -d "$NEW_DIR" ]] || mkdir "$NEW_DIR";
       bash "$0" -i "$f" -o "$NEW_DIR";
    else
        convert -colorspace GRAY "$f" "$GRAY/$(basename "$f")"
    fi
done