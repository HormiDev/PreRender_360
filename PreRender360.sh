#!/bin/sh
echo -ne '\033c\033]0;PreRender_360\a'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/PreRender360.x86_64" "$@"
