[ ! -f "$HOME/.config/shell/path.sh" ] || . "$HOME/.config/shell/path.sh"
[ ! -f "$HOME/.bash_aliases" ] || . "$HOME/.bash_aliases"
export EDITOR=vim

if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
