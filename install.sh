#!/bin/bash

set -e

here="$(dirname "$(realpath "$0")")"

mkdir -vp "$HOME/.local/bin"
ln -vs "$here/bin/dotcmd.sh" "$HOME/.local/bin/dotcmd"
