# Shared helpers for installing tools with their official installer scripts.
# Sourced by .bin/install.sh; relies on log, die, run, print_command and DRY_RUN.

TOOL_STAGING_DIR=
TOOL_CHILD_PID=

cleanup_tool_staging() {
    if [ -n "$TOOL_CHILD_PID" ]; then
        kill "$TOOL_CHILD_PID" 2>/dev/null || true
        TOOL_CHILD_PID=
    fi
    if [ -n "$TOOL_STAGING_DIR" ] && [ -d "$TOOL_STAGING_DIR" ]; then
        rm -rf "$TOOL_STAGING_DIR"
    fi
    TOOL_STAGING_DIR=
}

# Return success when NAME is already on PATH and starts, so the tool keeps
# its own update mechanism instead of being reinstalled on every run.
# A command that is present but cannot start stops the installer.
tool_is_available() {
    local name=$1
    local candidate

    candidate=$(command -v "$name" 2>/dev/null) || return 1
    "$candidate" --version >/dev/null 2>&1 ||
        die "$name is on PATH but cannot start: $candidate; repair or remove it, then rerun the installer"
    log "$name is already available: $candidate"
}

# Run a command in the background and wait for it, so HUP/INT/TERM sent to
# this script run the cleanup trap immediately instead of after the command
# exits. Standard input is passed through explicitly because asynchronous
# commands otherwise read from /dev/null.
run_tool_command() {
    local status=0

    exec 3<&0
    "$@" <&3 3<&- &
    TOOL_CHILD_PID=$!
    exec 3<&-
    wait "$TOOL_CHILD_PID" || status=$?
    TOOL_CHILD_PID=
    return "$status"
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
    local -a download=(curl -fsSL --retry 3 --connect-timeout 20 --max-time 120)

    shift 2
    while [ "$#" -gt 0 ] && [ "$1" != -- ]; do
        environment+=("$1")
        shift
    done
    [ "$#" -ge 2 ] || die "run_official_installer: missing interpreter for $name"
    shift

    log "Install $name with the official installer: $url"
    if [ "$DRY_RUN" -eq 1 ]; then
        print_command "${download[@]}" -o "<temporary>/install.sh" "$url"
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
    run_tool_command "${download[@]}" -o "$script" "$url" ||
        die "cannot download the $name installer: $url"
    run_tool_command env ${environment[@]+"${environment[@]}"} \
        "$1" "$script" "${@:2}" ||
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
