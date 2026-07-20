# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        # We have color support; assume it's compliant with Ecma-48
        # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
        # a case would tend to support setf rather than setaf.)
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm* | rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*) ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

[ -f "$HOME/.ghcup/env" ] && . "$HOME/.ghcup/env" # ghcup-env

# SSH agent for Git over SSH
__ssh_agent_env="$HOME/.ssh/agent.env"
__ssh_key_path="$HOME/.ssh/id_ed25519"

__ssh_file_mode() {
    if stat -c '%a' "$1" >/dev/null 2>&1; then
        stat -c '%a' "$1"
    else
        stat -f '%Lp' "$1"
    fi
}

__ssh_agent_env_safe() {
    [ -f "$__ssh_agent_env" ] &&
        [ -O "$__ssh_agent_env" ] &&
        [ "$(__ssh_file_mode "$__ssh_agent_env")" = 600 ]
}

__ssh_agent_ready() {
    ssh-add -l >/dev/null 2>&1
    case $? in
        0 | 1) return 0 ;;
        *) return 1 ;;
    esac
}

__ssh_key_loaded() {
    local key_fingerprint

    if [ -f "$__ssh_key_path.pub" ] && command -v ssh-keygen >/dev/null 2>&1; then
        key_fingerprint=$(ssh-keygen -lf "$__ssh_key_path.pub" 2>/dev/null | awk '{print $2}')
        [ -n "$key_fingerprint" ] &&
            ssh-add -l 2>/dev/null | awk '{print $2}' | grep -Fxq "$key_fingerprint"
        return $?
    fi

    ssh-add -l 2>/dev/null | grep -Fq "$__ssh_key_path"
}

if command -v ssh-agent >/dev/null 2>&1 && command -v ssh-add >/dev/null 2>&1; then
    if [ -d "$HOME/.ssh" ] && [ -O "$HOME/.ssh" ]; then
        chmod 700 "$HOME/.ssh"
    fi

    if ! __ssh_agent_ready && __ssh_agent_env_safe; then
        . "$__ssh_agent_env" >/dev/null
    fi

    if ! __ssh_agent_ready; then
        mkdir -p "$HOME/.ssh"
        if [ -O "$HOME/.ssh" ]; then
            chmod 700 "$HOME/.ssh"
        fi
        ssh-agent -s >"$__ssh_agent_env"
        chmod 600 "$__ssh_agent_env"
        . "$__ssh_agent_env" >/dev/null
    fi

    if __ssh_agent_ready && [ -f "$__ssh_key_path" ] && ! __ssh_key_loaded; then
        ssh-add -t 12h "$__ssh_key_path"
    fi
fi

unset __ssh_agent_env __ssh_key_path
unset -f __ssh_file_mode __ssh_agent_env_safe __ssh_agent_ready __ssh_key_loaded

# fbr - switch git branch
fbr() {
    local branches branch
    branches=$(git --no-pager branch -vv) &&
        branch=$(echo "$branches" | fzf +m) &&
        git switch $(echo "$branch" | awk '{print $1}' | sed "s/.* //")
}

# Starship prompt
eval "$(starship init bash)"
# 自作コマンドを読み込む
export PATH=$HOME/.bin:$PATH
# default editor
export EDITOR=vim
# >>> juliaup initialize >>>

# !! Contents within this block are managed by juliaup !!

case ":$PATH:" in
*:"$HOME"/.juliaup/bin:*) ;;

*)
    export PATH="$HOME/.juliaup/bin${PATH:+:${PATH}}"
    ;;
esac

# <<< juliaup initialize <<<

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/download/google-cloud-sdk/path.bash.inc" ]; then . "$HOME/download/google-cloud-sdk/path.bash.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/download/google-cloud-sdk/completion.bash.inc" ]; then . "$HOME/download/google-cloud-sdk/completion.bash.inc"; fi

# Cabalビルド用のパス
export PATH="$HOME/.cabal/bin:$PATH"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# fvm(flutter version management)
export PATH="$HOME/fvm/bin:$PATH"
export PATH="$PATH:$HOME/flutter/bin"

# Git config
# ----------
# create path to enable diff-highlight
export PATH="$PATH:/usr/local/share/git-core/contrib/diff-highlight"

# mise (runtime version manager)
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash)"
fi
