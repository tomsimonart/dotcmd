#!/bin/bash

set -e

log_dbg() {
    if [[ "$DEBUG" -eq 1 ]]; then
        printf "\x1b[1;30mDBG\x1b[0m %s\n" "$*" >&2
    fi
}

log_err() {
    printf "\x1b[1;31mERR\x1b[0m %s\n" "$*" >&2
}

log_msg() {
    printf "\x1b[1;34mMSG\x1b[0m %s\n" "$*" >&2
}

df_usage() {
    echo "$0 [add FILE|restore FILE|install]" >&2
    echo "" >&2
    echo "    add FILE       Add a new dotfile" >&2
    echo "    restore FILE   Restore the dotfile (untrack)" >&2
    echo "    install FILE   Install the dotfile (overwrite existing file)" >&2
    echo "" >&2
    echo "Any time a file is deleted/overwritten a backup is created right before (.bak)." >&2
    exit 1
}

here=$(dirname "$(realpath "$0")")
dfdir=$(realpath "$here/../df")  # This is where we store the dotfiles
log_dbg Creating directory "$dfdir"
mkdir -p "$dfdir"

file_in_dir() {
    # Returns 0 if file is inside the structure of directory
    local _file; _file="$1"
    local directory; directory="$2"
    if [[ $(realpath "$_file") == $(realpath "$directory")/* ]]; then
        return 0;
    fi
    return 1;
}

# is_already_tracked() {
#     # Checks if the dotfile is already tracked
#     # Returns 0 if yes, 1 if not
#     local file; file="$1"
#     if [[ -L "$file" ]]; then
#         if [[ ]]; then
#             return 0
#         fi
#     fi
#     return 1
# }

filter_dotfile() {
    # Checks if the dotfile can be processed:
    #  1. It's in the $HOME directory structure
    #  2. It's a normal file
    # If yes, return 0 and echo it's path relative to $HOME
    # If no, return 1
    # Warning, this does not check if the file is a link or not, just that it's in the
    # home directory and that it's a file.
    # This should be checked manually before calling the function.

    local file; file=$(realpath -m --no-symlinks --relative-to="$HOME" "$1")
    log_dbg Checking eligibility of "$HOME/$file"
    # Check that the file exists
    if [[ -f "$HOME/$file" ]]; then
        # Check that the file is in the directory
        if file_in_dir "$HOME/$file" "$HOME"; then
            log_dbg Got dotfile "$file"
            echo "$file"
            return 0
        else
            log_err The file is not in the home directory.
            return 1
        fi
    else
        log_err "$HOME/$file" is not a file or does not exist.
        return 1
    fi
}

backup_before_delete() {
    # Creates a backup of a file (this will delete the original file)
    local file; file="$1"
    log_msg Creating backup for "$file"
    mv --backup=numbered -v "$file" "$file.bak"
}

df_add() {
    local file; file="$1"

    # Check if it's not a symlink
    if [[ -L "$file" ]]; then
        log_err "$1 is a link, maybe it's tracked already ?"
        exit 1
    fi

    # Check that we can process the dotfile
    local dotfile;
    if ! dotfile=$(filter_dotfile "$file"); then
        exit 1
    fi

    # Remove any existing dotfile in the dfdir
    rm -v "$dfdir/$dotfile" 2>/dev/null || true
    # Copy the dotfile in the dotfile structure
    pushd "$HOME" > /dev/null
    cp -v --parents "$dotfile" "$dfdir"
    popd > /dev/null
    # Create a backup
    backup_before_delete "$HOME/$dotfile"
    # Create a link
    ln -s "$dfdir/$dotfile" "$HOME/$dotfile"
    log_msg "Dotfile tracked: $HOME/$dotfile"
}

clean_storage() {
    # Cleans empty directories from the dotfile storage
    log_dbg Cleaning up storage...
    find "$dfdir" -type d -empty -delete
}

df_restore() {
    # Move the file from the storage

    local file; file="$1"

    # Exclude non-symlink files
    if [[ ! -L "$file" ]]; then
        log_err "$1 is not tracked."
        exit 1
    fi

    # Check that we can process the dotfile
    local dotfile;
    if ! dotfile=$(filter_dotfile "$file"); then
        exit 1
    fi

    # Check that it's in the storage
    if [[ ! -f "$dfdir/$dotfile" ]]; then
        log_err "$dfdir/$dotfile does not exist, this means it's not tracked."
        exit 1
    fi

    # Remove the link to the tracked file (no need for a backup)
    log_msg Removing link "$HOME/$dotfile"
    rm -v "$HOME/$dotfile"
    log_msg Restore original dotfile
    mv -v "$dfdir/$dotfile" "$HOME/$dotfile"
    log_msg Dotfile untracked: "$HOME/$dotfile"

    clean_storage
}

df_install() {
    log_err not implemented
    exit 1
}

# Parse command
case "$1" in
    add)
        df_add "$2"
        ;;
    restore)
        df_restore "$2"
        ;;
    install)
        df_install "$2"
        ;;
    *)
        df_usage
        ;;
esac
