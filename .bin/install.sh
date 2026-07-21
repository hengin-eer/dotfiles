#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
DEBUG=0
BACKUP_DIR=
LEGACY_CONFIG=0
LEGACY_BIN=0

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run] [--debug] [--help]

Install the explicitly managed dotfiles into the current user's home.

Options:
  -n, --dry-run  Print changes without modifying files
  -d, --debug    Print each shell command while it runs
  -h, --help     Show this help
EOF
}

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

print_command() {
    printf '  +'
    printf ' %q' "$@"
    printf '\n'
}

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        print_command "$@"
    else
        "$@"
    fi
}

canonical_path() {
    local path=$1
    local directory
    local name

    directory=$(dirname "$path")
    name=$(basename "$path")
    directory=$(cd "$directory" 2>/dev/null && pwd -P) ||
        die "cannot resolve parent directory: $path"
    printf '%s/%s\n' "$directory" "$name"
}

resolved_link() {
    local path=$1
    local target

    target=$(readlink "$path") || return 1
    case "$target" in
    /*) ;;
    *) target=$(dirname "$path")/$target ;;
    esac
    canonical_path "$target"
}

link_points_to() {
    local destination=$1
    local source=$2
    local current

    [ -L "$destination" ] || return 1
    current=$(resolved_link "$destination") || return 1
    [ "$current" = "$(canonical_path "$source")" ]
}

ensure_backup_dir() {
    if [ -z "$BACKUP_DIR" ]; then
        BACKUP_DIR="$HOME/.dotbackup/$(date '+%Y%m%d-%H%M%S')"
        if [ -e "$BACKUP_DIR" ]; then
            BACKUP_DIR="$BACKUP_DIR-$$"
        fi
    fi
    run mkdir -p "$BACKUP_DIR"
}

backup_to() {
    local source=$1
    local relative_path=$2
    local destination

    [ -e "$source" ] || [ -L "$source" ] || return 0
    ensure_backup_dir
    destination="$BACKUP_DIR/$relative_path"
    log "Back up: $source -> $destination"
    run mkdir -p "$(dirname "$destination")"
    run mv "$source" "$destination"
}

backup_home_path() {
    local path=$1
    local relative_path=${path#"$HOME"/}

    [ "$relative_path" != "$path" ] ||
        die "refusing to back up a path outside HOME: $path"
    backup_to "$path" "$relative_path"
}

link_path() {
    local source=$1
    local destination=$2

    [ -e "$source" ] || die "managed source does not exist: $source"

    if link_points_to "$destination" "$source"; then
        log "Already linked: $destination"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        case "$destination" in
        "$HOME/.config/"*)
            if [ "$LEGACY_CONFIG" -eq 1 ]; then
                log "Link: $destination -> $source"
                print_command ln -s "$source" "$destination"
                return 0
            fi
            ;;
        "$HOME/.bin/"*)
            if [ "$LEGACY_BIN" -eq 1 ]; then
                log "Link: $destination -> $source"
                print_command ln -s "$source" "$destination"
                return 0
            fi
            ;;
        esac
    fi

    if [ -e "$destination" ] || [ -L "$destination" ]; then
        backup_home_path "$destination"
    fi

    log "Link: $destination -> $source"
    run mkdir -p "$(dirname "$destination")"
    run ln -s "$source" "$destination"
}

move_config_entry() {
    local source=$1
    local relative_path=${source#"$DOTDIR/.config/"}
    local destination="$HOME/.config/$relative_path"

    [ "$relative_path" != "$source" ] ||
        die "refusing to migrate a path outside the repository config: $source"
    if [ "$DRY_RUN" -eq 0 ] &&
        { [ -e "$destination" ] || [ -L "$destination" ]; }; then
        die "config migration destination already exists: $destination"
    fi

    log "Migrate unmanaged config: $source -> $destination"
    run mkdir -p "$(dirname "$destination")"
    run mv "$source" "$destination"
}

move_unmanaged_children() {
    local directory=$1
    local managed_name=$2
    local entry

    [ -d "$directory" ] || return 0
    for entry in "$directory"/* "$directory"/.[!.]* "$directory"/..?*; do
        [ -e "$entry" ] || [ -L "$entry" ] || continue
        [ "$(basename "$entry")" = "$managed_name" ] && continue
        move_config_entry "$entry"
    done
}

migrate_legacy_config() {
    local destination="$HOME/.config"
    local entry
    local name

    if [ -L "$destination" ]; then
        link_points_to "$destination" "$DOTDIR/.config" ||
            die "$destination is a symlink not owned by this repository"
        LEGACY_CONFIG=1
        log "Migrate legacy whole-directory link: $destination"
        run rm "$destination"
        run mkdir -p "$destination"

        for entry in \
            "$DOTDIR/.config"/* \
            "$DOTDIR/.config"/.[!.]* \
            "$DOTDIR/.config"/..?*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            name=$(basename "$entry")
            case "$name" in
            nvim | wezterm | gh | mdts) ;;
            *) move_config_entry "$entry" ;;
            esac
        done
        move_unmanaged_children "$DOTDIR/.config/gh" config.yml
        move_unmanaged_children "$DOTDIR/.config/mdts" config.json
    elif [ -e "$destination" ] && [ ! -d "$destination" ]; then
        die "$destination exists but is not a directory"
    else
        run mkdir -p "$destination"
    fi
}

migrate_legacy_bin() {
    local destination="$HOME/.bin"

    if [ -L "$destination" ]; then
        link_points_to "$destination" "$DOTDIR/.bin" ||
            die "$destination is a symlink not owned by this repository"
        LEGACY_BIN=1
        log "Migrate legacy whole-directory link: $destination"
        backup_to "$DOTDIR/.bin/todome" ".bin/todome"
        run rm "$destination"
        run mkdir -p "$destination"
    elif [ -e "$destination" ] && [ ! -d "$destination" ]; then
        die "$destination exists but is not a directory"
    else
        backup_to "$DOTDIR/.bin/todome" ".bin/todome"
        run mkdir -p "$destination"
    fi
}

remove_legacy_link() {
    local destination=$1
    local source=$2

    if link_points_to "$destination" "$source"; then
        log "Remove obsolete link: $destination"
        run rm "$destination"
    fi
}

remove_git_section() {
    local section=$1

    if git config --file "$HOME/.gitconfig" --get-regexp "^${section}\\." \
        >/dev/null 2>&1; then
        run git config --file "$HOME/.gitconfig" --remove-section "$section"
    fi
}

ensure_git_include() {
    local include_path='~/.gitconfig_shared'

    if [ "$DRY_RUN" -eq 1 ] && link_points_to "$HOME/.gitconfig" "$DOTDIR/.gitconfig"; then
        log "Migrate personal Git config out of the repository"
        print_command rm "$HOME/.gitconfig"
        print_command mv "$DOTDIR/.gitconfig" "$HOME/.gitconfig"
        print_command git config --file "$HOME/.gitconfig" --remove-section init
        print_command git config --file "$HOME/.gitconfig" --remove-section pager
        print_command git config --file "$HOME/.gitconfig" --add include.path "$include_path"
        return 0
    fi

    if link_points_to "$HOME/.gitconfig" "$DOTDIR/.gitconfig"; then
        log "Migrate personal Git config out of the repository"
        run rm "$HOME/.gitconfig"
        run mv "$DOTDIR/.gitconfig" "$HOME/.gitconfig"
        remove_git_section init
        remove_git_section pager
    elif [ -L "$HOME/.gitconfig" ]; then
        die "$HOME/.gitconfig is a symlink not owned by this repository"
    fi

    run mkdir -p "$HOME"
    if [ ! -e "$HOME/.gitconfig" ]; then
        run touch "$HOME/.gitconfig"
    fi

    if ! git config --file "$HOME/.gitconfig" --get-all include.path 2>/dev/null |
        grep -Fqx "$include_path"; then
        log "Add shared Git config include"
        run git config --file "$HOME/.gitconfig" --add include.path "$include_path"
    fi
}

install_managed_paths() {
    local source
    local destination

    while IFS='|' read -r source destination; do
        [ -n "$source" ] || continue
        link_path "$DOTDIR/$source" "$HOME/$destination"
    done <<'EOF'
.bash_aliases|.bash_aliases
.bash_profile|.bash_profile
.bashrc|.bashrc
.editorconfig|.editorconfig
.gitconfig_shared|.gitconfig_shared
.tmux.conf|.tmux.conf
.vimrc|.vimrc
.bin/git-nlog|.bin/git-nlog
.bin/git-ndiff|.bin/git-ndiff
.bin/install.sh|.bin/install.sh
.config/nvim|.config/nvim
.config/wezterm|.config/wezterm
.config/gh/config.yml|.config/gh/config.yml
.config/mdts/config.json|.config/mdts/config.json
.config/mise/global.toml|.config/mise/config.toml
EOF
}

install_fonts() {
    local font_dir
    local font

    case "$OS" in
    Linux) font_dir="$HOME/.local/share/fonts" ;;
    Darwin) font_dir="$HOME/Library/Fonts" ;;
    esac

    run mkdir -p "$font_dir"
    while IFS= read -r font; do
        link_path "$font" "$font_dir/$(basename "$font")"
    done < <(
        find "$DOTDIR/fonts" -type f \( -name '*.ttf' -o -name '*.otf' \) -print |
            sort
    )

    if [ "$OS" = Linux ] && command -v fc-cache >/dev/null 2>&1; then
        log "Refresh font cache"
        run fc-cache -f "$font_dir"
    fi
}

install_vim_plug() {
    local plug_path="$HOME/.vim/autoload/plug.vim"

    if [ -f "$plug_path" ]; then
        log "vim-plug is already installed"
        return 0
    fi

    log "Install vim-plug: $plug_path"
    if [ "$DRY_RUN" -eq 1 ]; then
        print_command curl -fLo "$plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    else
        curl -fLo "$plug_path" --create-dirs \
            https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    -d | --debug) DEBUG=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        die "unknown option: $1"
        ;;
    esac
    shift
done

if [ "$DEBUG" -eq 1 ]; then
    set -x
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
DOTDIR=$(cd "$SCRIPT_DIR/.." && pwd -P)
OS=$(uname -s)

case "$OS" in
Linux | Darwin) ;;
*) die "unsupported operating system: $OS" ;;
esac

[ "$DOTDIR" != "$HOME" ] ||
    die "the dotfiles repository must not be the home directory"

log "Dotfiles source: $DOTDIR"
log "Target home: $HOME"
[ "$DRY_RUN" -eq 0 ] || log "Dry-run mode: no files will be changed"

migrate_legacy_config
migrate_legacy_bin
remove_legacy_link "$HOME/.gitignore" "$DOTDIR/.gitignore"
ensure_git_include
install_managed_paths
install_fonts
install_vim_plug

if [ -n "$BACKUP_DIR" ]; then
    log "Backup: $BACKUP_DIR"
fi
log "Dotfiles installation completed"
