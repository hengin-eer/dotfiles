#!/usr/bin/env bash
set -euo pipefail

DRY_RUN=0
DEBUG=0
BACKUP_DIR=
LEGACY_CONFIG=0
LEGACY_BIN=0
NVIM_VERSION=${NVIM_VERSION:-v0.12.5}
NVIM_STAGING_DIR=

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run] [--debug] [--help]

Install the explicitly managed dotfiles into the current user's home.

Options:
  -n, --dry-run  Print changes without modifying files
  -d, --debug    Print each shell command while it runs
      --nvim-version VERSION  Select a checksum-pinned Neovim release
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
    local suffix
    local part

    directory=$(dirname "$path")
    suffix=$(basename "$path")
    while [ ! -d "$directory" ]; do
        [ "$directory" != / ] || die "cannot resolve parent directory: $path"
        part=$(basename "$directory")
        suffix="$part/$suffix"
        directory=$(dirname "$directory")
    done
    directory=$(cd "$directory" 2>/dev/null && pwd -P) || return 1
    printf '%s/%s\n' "${directory%/}" "$suffix"
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
    local allow_missing_source=${3:-0}

    if [ ! -e "$source" ] && ! { [ "$DRY_RUN" -eq 1 ] && [ "$allow_missing_source" -eq 1 ]; }; then
        die "managed source does not exist: $source"
    fi

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

managed_paths() {
    cat <<'EOF'
.bash_aliases|.bash_aliases
.bash_profile|.bash_profile
.bashrc|.bashrc
.zprofile|.zprofile
.zshrc|.zshrc
.config/shell/path.sh|.config/shell/path.sh
.editorconfig|.editorconfig
.gitconfig_shared|.gitconfig_shared
.vimrc|.vimrc
.codex/AGENTS.md|.codex/AGENTS.md
.codex/rules/herdr-git.rules|.codex/rules/herdr-git.rules
.bin/git-nlog|.bin/git-nlog
.bin/git-ndiff|.bin/git-ndiff
.bin/install.sh|.bin/install.sh
.bin/nvim-versions.tsv|.bin/nvim-versions.tsv
.config/nvim|.config/nvim
.config/wezterm|.config/wezterm
.config/herdr/config.toml|.config/herdr/config.toml
.config/gh/config.yml|.config/gh/config.yml
.config/mdts/config.json|.config/mdts/config.json
.config/mise/global.toml|.config/mise/config.toml
EOF
}

config_path_kind() {
    local candidate=$1
    local source
    local destination
    local managed
    local has_child=0

    while IFS='|' read -r source destination; do
        case "$source" in
        .config/*)
            managed="$DOTDIR/$source"
            if [ "$candidate" = "$managed" ]; then
                printf 'exact\n'
                return 0
            fi
            case "$managed" in
            "$candidate"/*) has_child=1 ;;
            esac
            ;;
        esac
    done <<EOF
$(managed_paths)
EOF

    if [ "$has_child" -eq 1 ]; then
        printf 'parent\n'
    else
        printf 'unmanaged\n'
    fi
}

migrate_unmanaged_config_tree() {
    local source=$1
    local entry
    local kind

    kind=$(config_path_kind "$source")
    case "$kind" in
    exact) return 0 ;;
    unmanaged)
        move_config_entry "$source"
        return 0
        ;;
    parent)
        if [ -L "$source" ]; then
            die "managed config parent is a symlink and cannot be migrated safely: $source"
        fi
        [ -d "$source" ] || die "managed config parent is not a directory: $source"
        for entry in "$source"/* "$source"/.[!.]* "$source"/..?*; do
            [ -e "$entry" ] || [ -L "$entry" ] || continue
            migrate_unmanaged_config_tree "$entry"
        done
        ;;
    esac
}

migrate_legacy_config() {
    local destination="$HOME/.config"
    local entry

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
            migrate_unmanaged_config_tree "$entry"
        done
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
    done < <(managed_paths)
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

sha256_file() {
    local path=$1

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$path" | awk '{ print $1 }'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$path" | awk '{ print $1 }'
    else
        die "SHA-256 utility not found (install sha256sum or shasum)"
    fi
}

nvim_checksum() {
    local version=$1
    local package=$2
    local checksum_file="$DOTDIR/.bin/nvim-versions.tsv"
    local result

    [ -f "$checksum_file" ] || die "Neovim version manifest not found: $checksum_file"
    result=$(awk -v version="$version" -v package="$package" \
        '$1 == version && $2 == package { print $3 }' "$checksum_file")
    case "$result" in
    '' | *$'\n'*) die "unsupported Neovim version or package: $version/$package" ;;
    *[!0123456789abcdef]*) die "invalid SHA-256 in manifest for $version/$package" ;;
    esac
    [ "${#result}" -eq 64 ] || die "invalid SHA-256 in manifest for $version/$package"
    printf '%s\n' "$result"
}

validate_neovim() {
    local candidate=$1
    local version_output
    local version_number
    local major
    local minor

    if ! version_output=$("$candidate" --version 2>/dev/null); then
        die "Neovim cannot start: $candidate; install Neovim 0.11 or newer, or repair this executable"
    fi
    version_number=$(printf '%s\n' "$version_output" |
        sed -n '1s/^NVIM v\([0-9][0-9.]*\).*/\1/p')
    [ -n "$version_number" ] || die "cannot read Neovim version from: $candidate"
    major=${version_number%%.*}
    minor=${version_number#*.}
    minor=${minor%%.*}
    if [ "$major" -lt 1 ] && [ "$minor" -lt 11 ]; then
        die "Neovim 0.11 or newer is required; found $version_number at $candidate"
    fi
    if ! "$candidate" --headless -u NONE \
        -c 'lua assert(type(vim.lsp.enable) == "function")' \
        -c 'lua assert(#vim.api.nvim_get_runtime_file("doc/options.txt", false) > 0)' \
        -c 'qa!' >/dev/null 2>&1; then
        die "Neovim API or runtime check failed: $candidate; repair it or install Neovim 0.11 or newer"
    fi
}

validate_archive_members() {
    local archive=$1
    local package=$2
    local listing=$3
    local member

    tar -tzf "$archive" > "$listing" || die "cannot list Neovim archive: $archive"
    while IFS= read -r member; do
        member=${member%/}
        case "$member" in
        "$package" | "$package/"*) ;;
        *) die "unexpected path in Neovim archive: $member" ;;
        esac
        case "/$member/" in
        *"/../"* | *"/./"*) die "unsafe path in Neovim archive: $member" ;;
        esac
    done < "$listing"

    # Official release archives contain only regular files and directories.
    if ! tar -tvzf "$archive" | awk 'substr($0, 1, 1) != "-" && substr($0, 1, 1) != "d" { exit 1 }'; then
        die "links and special files are not allowed in Neovim archives: $archive"
    fi
    grep -Fx "$package/bin/nvim" "$listing" >/dev/null ||
        die "archive does not contain $package/bin/nvim"
    grep -Fx "$package/share/nvim/runtime/doc/options.txt" "$listing" >/dev/null ||
        die "archive does not contain the Neovim runtime"
}

cleanup_nvim_staging() {
    if [ -n "$NVIM_STAGING_DIR" ] && [ -d "$NVIM_STAGING_DIR" ]; then
        rm -rf "$NVIM_STAGING_DIR"
    fi
    NVIM_STAGING_DIR=
}

install_neovim() {
    local architecture
    local package
    local install_dir
    local archive
    local expected_checksum
    local actual_checksum
    local candidate
    local listing
    local opt_dir="$HOME/.local/opt"
    local release_url

    architecture=$(uname -m)
    case "$OS/$architecture" in
    Darwin/arm64) package=nvim-macos-arm64 ;;
    Darwin/x86_64) package=nvim-macos-x86_64 ;;
    Linux/aarch64 | Linux/arm64) package=nvim-linux-arm64 ;;
    Linux/x86_64) package=nvim-linux-x86_64 ;;
    *) die "unsupported Neovim platform: $OS/$architecture" ;;
    esac
    expected_checksum=$(nvim_checksum "$NVIM_VERSION" "$package")
    install_dir="$opt_dir/$package"

    if command -v nvim >/dev/null 2>&1; then
        candidate=$(command -v nvim)
        validate_neovim "$candidate"
        log "Neovim is available and compatible: $candidate"
        return 0
    fi

    if [ -e "$install_dir" ] || [ -L "$install_dir" ]; then
        candidate="$install_dir/bin/nvim"
        [ -x "$candidate" ] ||
            die "incomplete Neovim installation at $install_dir; move it aside, then rerun the installer"
        validate_neovim "$candidate"
        link_path "$candidate" "$HOME/.local/bin/nvim"
        log "Neovim is available: $candidate"
        return 0
    fi

    archive=${NVIM_ARCHIVE:-}
    release_url="https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$package.tar.gz"
    if [ -n "$archive" ]; then
        [ -f "$archive" ] || die "Neovim archive not found: $archive"
        log "Use local Neovim archive: $archive"
    else
        archive="$opt_dir/$package-$NVIM_VERSION.tar.gz"
        log "Download Neovim $NVIM_VERSION ($package), SHA-256 $expected_checksum"
        log "  URL: $release_url"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "Stage archive, verify SHA-256 and contents, then validate Neovim before installing"
        if [ -n "${NVIM_ARCHIVE:-}" ]; then
            log "  + verify checksum: $expected_checksum"
        else
            print_command curl -fL --retry 3 -o "<temporary>/$package.tar.gz" "$release_url"
        fi
        print_command tar -xzf "${NVIM_ARCHIVE:-<temporary>/$package.tar.gz}" -C "<temporary>"
        link_path "$install_dir/bin/nvim" "$HOME/.local/bin/nvim" 1
        return 0
    fi

    mkdir -p "$opt_dir"
    NVIM_STAGING_DIR=$(mktemp -d "$opt_dir/.nvim-install.XXXXXX") ||
        die "cannot create Neovim staging directory under $opt_dir"
    trap cleanup_nvim_staging EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if [ -z "${NVIM_ARCHIVE:-}" ]; then
        archive="$NVIM_STAGING_DIR/$package.tar.gz"
        curl -fL --retry 3 -o "$archive" "$release_url"
    fi
    actual_checksum=$(sha256_file "$archive")
    [ "$actual_checksum" = "$expected_checksum" ] ||
        die "Neovim archive SHA-256 mismatch: expected $expected_checksum, got $actual_checksum"

    listing="$NVIM_STAGING_DIR/contents.txt"
    validate_archive_members "$archive" "$package" "$listing"
    tar -xzf "$archive" -C "$NVIM_STAGING_DIR" || die "Neovim archive extraction failed"
    candidate="$NVIM_STAGING_DIR/$package/bin/nvim"
    [ -x "$candidate" ] || die "archive does not contain executable $package/bin/nvim"
    validate_neovim "$candidate"

    [ ! -e "$install_dir" ] && [ ! -L "$install_dir" ] ||
        die "Neovim install destination appeared during installation: $install_dir"
    mv "$NVIM_STAGING_DIR/$package" "$install_dir"
    cleanup_nvim_staging
    trap - EXIT HUP INT TERM
    candidate="$install_dir/bin/nvim"
    link_path "$candidate" "$HOME/.local/bin/nvim"
    log "Neovim is available: $candidate"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
    -n | --dry-run) DRY_RUN=1 ;;
    -d | --debug) DEBUG=1 ;;
    --nvim-version)
        [ "$#" -ge 2 ] || die "--nvim-version requires a version such as v0.12.5"
        NVIM_VERSION=$2
        shift
        ;;
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
remove_legacy_link "$HOME/.tmux.conf" "$DOTDIR/.tmux.conf"
ensure_git_include
install_managed_paths
install_fonts
# Use the repository copy as the installed link does not exist in dry-run mode.
. "$DOTDIR/.config/shell/path.sh"
install_neovim
install_vim_plug

if [ -n "$BACKUP_DIR" ]; then
    log "Backup: $BACKUP_DIR"
fi
log "Dotfiles installation completed"
log "Open a new terminal, or source ~/.config/shell/path.sh to update PATH in this shell"
