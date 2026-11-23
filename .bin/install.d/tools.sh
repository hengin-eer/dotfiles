# Shared helpers for installing tools with their official installer scripts.
# Sourced by .bin/install.sh; relies on log, die, run, print_command and DRY_RUN.

TOOL_STAGING_DIR=

cleanup_tool_staging() {
    if [ -n "$TOOL_STAGING_DIR" ] && [ -d "$TOOL_STAGING_DIR" ]; then
        rm -rf "$TOOL_STAGING_DIR"
    fi
    TOOL_STAGING_DIR=
}

# Return success when NAME is already available, so the tool keeps its own
# update mechanism instead of being reinstalled on every run.
tool_is_available() {
    local name=$1
    local candidate

    candidate=$(command -v "$name" 2>/dev/null) || return 1
    log "$name is already available: $candidate"
}

# Download an official installer to a temporary file and run it.
#
# Usage:
#   run_official_installer NAME URL [VAR=VALUE...] -- INTERPRETER [ARGS...]
#
# The script is saved before it runs, so a dropped connection never executes
# a truncated script the way `curl ... | sh` can.
run_official_installer() {
    local name=$1
    local url=$2
    local script
    local -a environment=()

    shift 2
    while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
        environment+=("$1")
        shift
    done
    [ "$#" -ge 2 ] || die "run_official_installer: missing interpreter for $name"
    shift

    log "Install $name with the official installer: $url"
    if [ "$DRY_RUN" -eq 1 ]; then
        print_command curl -fsSL --retry 3 -o "<temporary>/install.sh" "$url"
        print_command env ${environment[@]+"${environment[@]}"} \
            "$1" "<temporary>/install.sh" "${@:2}"
        return 0
    fi

    TOOL_STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-$name.XXXXXX") ||
        die "cannot create a temporary directory for the $name installer"
    trap cleanup_tool_staging EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    script="$TOOL_STAGING_DIR/install.sh"
    curl -fsSL --retry 3 -o "$script" "$url" ||
        die "cannot download the $name installer: $url"
    env ${environment[@]+"${environment[@]}"} "$1" "$script" "${@:2}" ||
        die "the official $name installer failed; rerun it or install $name manually"

    cleanup_tool_staging
    trap - EXIT HUP INT TERM
}

# Confirm that the installer left a runnable command at the expected path.
verify_tool() {
    local name=$1
    local executable=$2

    [ "$DRY_RUN" -eq 0 ] || return 0
    [ -x "$executable" ] ||
        die "$name was not installed at $executable"
    "$executable" --version >/dev/null 2>&1 ||
        die "$name was installed but cannot start: $executable"
    log "$name is available: $executable"
}
