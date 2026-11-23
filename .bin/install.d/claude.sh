# Claude Code: https://code.claude.com/docs/en/setup
# The native installer places the launcher at ~/.local/bin/claude and keeps
# Claude Code up to date by itself. Authentication is done on first launch.
# Set CLAUDE_CODE_RELEASE to stable, latest or a version such as 2.1.0.

CLAUDE_INSTALLER_URL=${CLAUDE_INSTALLER_URL:-https://claude.ai/install.sh}
CLAUDE_CODE_RELEASE=${CLAUDE_CODE_RELEASE:-stable}

install_claude_code() {
    tool_is_available claude && return 0
    run_official_installer claude "$CLAUDE_INSTALLER_URL" \
        -- bash "$CLAUDE_CODE_RELEASE"
    verify_tool claude "$HOME/.local/bin/claude"
}
