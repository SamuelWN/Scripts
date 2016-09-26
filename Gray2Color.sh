#!/bin/bash
# @author   Samuel Walters-Nevet                                                                                                #
# @date     Summer, 2016                                                                                                        #
# @brief    Batch converter pictures from grayscale to color, preserving folder structure                                       #
# @file     Gray2Color.sh                                                                                                       #
#                                                                                                                               #
# Prerequisits:                                                                                                                 #
#   caffe (https://github.com/BVLC/caffe/wiki/Ubuntu-16.04-or-15.10-Installation-Guide)                                         #
#   autocolorize (sudo -H pip install autocolorize)                                                                             #
#################################################################################################################################




GRAY=""
COLOR=""

while getopts ":i:o:" opt
do
    case $opt in
    i)  GRAY="$OPTARG";;
    o)  COLOR="$OPTARG";;
    *)  echo "Un-imlemented option chosen"
        exit;;
    esac
done

[[ -z "$GRAY" ]] && GRAY="$PWD"

[[ -z "$COLOR" ]] && COLOR="$(dirname "$GRAY")/COLOR"
[[ ! -d "$COLOR" ]] && mkdir "$COLOR"

for f in "$GRAY"/*; do
    if [[ -d "$f" ]]; then
       NEW_DIR="$COLOR/${f##*"$GRAY"}"
       [[ -d "$NEW_DIR" ]] || mkdir "$NEW_DIR";
       bash "$0" -i "$f" -o "$NEW_DIR";
    else
        filename="$(basename "$f")"
        autocolorize -d cpu -v -o "$COLOR/${filename%.*}.jpg" "$f"
    fi
done