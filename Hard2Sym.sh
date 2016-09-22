#!/bin/bash

# Configure script environment
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
set -o nounset

if [[ $# > 0 ]]; then dir="$1"
else dir="$PWD"

# For each path which has multiple links
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# (except ones containing newline)
last_inode=
while IFS= read -r path_info
do
   inode=${path_info%%:*}
   path=${path_info#*:}
   if [[ $last_inode != $inode ]]; then
       last_inode=$inode
       path_to_keep=$path
   else
       echo "DEBUG: ln -s '$path_to_keep' '$path'"
       rm "$path"
       ln -s "$path_to_keep" "$path"
   fi
done < <( find -P "$dir" -type f -links +1 -iname '*.mp4' ! -wholename '*
*' -printf '%i:%p\n' | sort --field-separator=: )

# Warn about any excluded files
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
buf=$( find "$dir" -type f -links +1 -wholename '*
*' )
if [[ $buf != '' ]]; then
    echo 'Some files not processed because their paths contained newline(s):'$'\n'"$buf"
fi

exit 0
