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

log_wrn() {
    printf "\x1b[1;33mWRN\x1b[0m %s\n" "$*" >&2
}

log_msg() {
    printf "\x1b[1;34mMSG\x1b[0m %s\n" "$*" >&2
}

log_ok() {
    printf "\x1b[1;32mOK!\x1b[0m %s\n" "$*" >&2
}

df_usage() {
    echo "$0 [add FILE|restore FILE|install [FILE|all]]" >&2
    echo "" >&2
    echo "    add FILE       Add a new dotfile" >&2
    echo "    restore FILE   Restore the dotfile (untrack)" >&2
    echo "    install FILE|all   Install the dotfile (overwrite existing file)" >&2
    echo "" >&2
    echo "FILE is always the path to the normal file, not a path to the storage." >&2
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

dotfile_realpath() {
    # Get the path of the file requested relative to home
    realpath -m --no-symlinks --relative-to="$HOME" "$1"
}

dotfile_realpath_from_storage() {
    # Get the path of the file requested relative to home from a path in the storage
    realpath -m --no-symlinks --relative-to="$dfdir" "$1"
}

filter_dotfile() {
    # Checks if the dotfile can be processed:
    #  1. It's in the $HOME directory structure
    #  2. It's a normal file
    # If yes, return 0 and echo it's path relative to $HOME
    # If no, return 1
    # Warning, this does not check if the file is a link or not, just that it's in the
    # home directory and that it's a file.
    # This should be checked manually before calling the function.

    local file; file=$(dotfile_realpath "$1")
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
    log_ok "Dotfile tracked: $HOME/$dotfile"
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
    log_ok Dotfile untracked: "$HOME/$dotfile"

    clean_storage
}

df_install_all() {
    # Get all files from the storage and install them
    find "$dfdir" -type f -not -path "$dfdir/.git/*" -print0 | while IFS= read -r -d '' file; do
        dotfile=$(dotfile_realpath_from_storage "$file")
        df_install_one "$HOME/$dotfile"
    done

}

df_install_one() {
    # Install a single dotfile from the storage
    local file; file="$1"

    # Check that we can process the dotfile
    local dotfile;
    dotfile=$(dotfile_realpath "$file")
    log_msg "Installing dotfile: '$dfdir/$file'"

    # Check that it exists in the storage
    if [[ ! -f "$dfdir/$dotfile" ]]; then
        log_err "Dotfile is not in the storage: $dfdir/$dotfile."
        exit 1
    fi

    # If a file exists and it's not a symlink then back it up
    if [[ -f "$HOME/$dotfile" && ! -L "$HOME/$dotfile" ]]; then
        backup_before_delete "$HOME/$dotfile"
    fi

    # If it's a symlink just remove it
    if [[ -L "$HOME/$dotfile" ]]; then
        log_wrn "This dotfile is already a symlink to '$(readlink "$HOME/$dotfile")', it will be replaced."
        rm -v "$HOME/$dotfile"
    fi

    # Create missing directories
    mkdir -p "$(dirname "$HOME/$dotfile")"

    # Create a link to the dotfile
    ln -s "$dfdir/$dotfile" "$HOME/$dotfile"
    log_ok "Dotfile installed: $HOME/$dotfile"
}

df_install() {
    # Selects the installation function
    if [[ $1 == "all" ]]; then
        df_install_all
    else
        df_install_one "$1"
    fi
}

df_git() {
    log_msg "Entering $dfdir to run git."
    pushd "$dfdir" > /dev/null
    git "$@"
    popd > /dev/null
    log_msg Leaving storage directory.
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
    git)
        shift
        df_git "$@"
        ;;
    *)
        df_usage
        ;;
esac

exit 0
