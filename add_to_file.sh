#!/bin/sh

if [[ $# -ne 2 ]];then
  echo " add to file need context and filename "
  exit 1
fi

context=$1
filename=$2

# * is escape char in grep. need add more
grep_target=${context//\*/\\\*}

echo wrie"$context" to "$filename"

if [[ ! -f "$filename" ]]; then
    echo "$context" >> "$filename"
    exit 0
fi

if ! grep "$context" "$filename"; then
    echo "$context" >> "$filename"
fi
