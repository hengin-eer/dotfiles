# Shared by Bash, zsh and the installer. Keep repeated sourcing idempotent.
_dotfiles_prepend_path() {
    case ":${PATH:-}:" in
        *:"$1":*) ;;
        *) PATH="$1${PATH:+:$PATH}" ;;
    esac
}

# Homebrew: Apple Silicon and Intel installations (also non-login shells).
for _dotfiles_bin in /usr/local/bin /usr/local/sbin /opt/homebrew/bin /opt/homebrew/sbin; do
    [ ! -d "$_dotfiles_bin" ] || _dotfiles_prepend_path "$_dotfiles_bin"
done
_dotfiles_prepend_path "$HOME/.bin"
_dotfiles_prepend_path "$HOME/.local/bin"
export PATH
unset _dotfiles_bin
unset -f _dotfiles_prepend_path
