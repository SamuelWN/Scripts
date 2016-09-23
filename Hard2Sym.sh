#!/bin/bash

# Configure script environment
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
set -o nounset

if [[ $# > 0 ]]; then dir="$1"
else dir="$PWD";
fi

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
        relative_path="$(realpath --relative-to="$(dirname "$path")" "$path_to_keep")"
        echo -e "DEBUG:\nln -s '$relative_path' '$path'"
        rm "$path"
        ln -s "$relative_path" "$path"
    fi
done < <( find -P "$dir" -type f -links +1 -iname '*.*' ! -wholename '*
*' -printf '%i:%p\n' | sort --field-separator=: )

# Warn about any excluded files
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
buf=$( find "$dir" -type f -links +1 -wholename '*
*' )
if [[ $buf != '' ]]; then
    echo 'Some files not processed because their paths contained newline(s):'$'\n'"$buf"
fi

exit 0
