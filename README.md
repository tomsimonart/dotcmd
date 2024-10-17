## Dotcmd

Dotcmd is a simple minimalistic command line tool to manage dotfiles.

Dotcmd will track dotfiles in the `df/` directory (referenced as "the storage directory"), and in the host system those dotfiles will be available as symlinks to `df/`. For example:

`$HOME/.config/alacritty/alacritty.toml -> $HOME/dotcmd/df/.config/alacritty/alacritty.toml`

A couple things to know:

1. Original directory structure is kept within the storage directory.
2. Dotcmd is only compatible with normal files within your home directory, anything else will result in an error.
3. Relative paths are supported as long as the real path is in the home directory.
4. Recursive backups are created automatically before any destructive actions (like removing a file). This means `$HOME/.bashrc.bak.~1~` will be created if `$HOME/.bashrc` and `$HOME/.bashrc.bak` exist. Dotcmd uses the numbered backup feature of the `mv` and `cp` commands internally.

## Topics

### Installation

run `./install.sh` then open a new shell, check if the `dotcmd` is available.  If not, make sure `$HOME/.local/bin` is in your `$PATH`.

### Guide: Tracking a dotfile on git

This will put the file in your storage directory and symlink to it from the original path of the file.

```shell
# Make sure to initialize your repository the first time !
dotcmd git init  # Initialize a git repository inside the storage directory.

dotcmd add ~/.bashrc  # Add the file to your dotfile storage

# Track the file
dotcmd git status  # Check that the tracking worked
dotcmd git add .bashrc  # With the git command we are relative to our storage directory
dotcmd git commit -m "Add .bashrc"
# Here you might want to add a remote to backup your dotfiles
dotcmd git remote add ...  # Add your remote
dotcmd git push  # Push the changes on the remote
```

### Guide: Untracking a dotfile

This will remove the file from the storage and put it back on the host system where it was originally. (It will also clean empty directories in the storage).

Good to know: You can not restore a dotfile that's not tracked correctly (installed). This means that if you want to use a dotfile that's in your storage but nowhere in the system, you should use install first.

```shell
dotcmd restore ~/.bashrc

# You will need to manually approve this deletion with git
dotcmd git rm .bashrc  # With the git command we are relative to our storage directory
dotcmd git commit -m "Untrack .bashrc"
dotcmd git push  # Push the changes on the remote
```

### Guide: Install a dotfile

When you are on a new system and you want to install the dotfiles you tracked, you can use this process.

```shell
dotcmd install ~/.bashrc  # Reference the path where the file should be installed
```

There is also an option to install all dotfiles (can be useful for a distro re-install).
```shell
dotcmd install all
```


## Contributing

1. Install and use shellcheck.
2. Keep it as simple as possible.
