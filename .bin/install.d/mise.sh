# mise: https://mise.jdx.dev/installing-mise.html
# The official script verifies the release SHA-256 and does not edit shell
# startup files; .zshrc and .bashrc activate mise when it is on PATH.
# Set MISE_VERSION (for example v2026.11.12) to pin a release.

MISE_INSTALLER_URL=${MISE_INSTALLER_URL:-https://mise.run}

install_mise() {
    local executable="$HOME/.local/bin/mise"

    tool_is_available mise && return 0
    run_official_installer mise "$MISE_INSTALLER_URL" \
        MISE_INSTALL_PATH="$executable" -- sh
    verify_tool mise "$executable"
}
