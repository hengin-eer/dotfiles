# Codex CLI: standalone installer from https://github.com/openai/codex
# It installs under ~/.codex/packages/standalone and links ~/.local/bin/codex.
# CODEX_INSTALL_DIR is pinned to ~/.local/bin, which is already on PATH
# through ~/.config/shell/path.sh, so the installer never adds a PATH block to
# the managed shell files even when the caller exported another directory.
# Set CODEX_RELEASE to pin a version; the default is the latest release.

CODEX_INSTALLER_URL=${CODEX_INSTALLER_URL:-https://chatgpt.com/codex/install.sh}

install_codex() {
    local bin_dir="$HOME/.local/bin"

    tool_is_available codex && return 0
    # Non-interactive mode skips the "Start Codex now?" prompt.
    run_official_installer codex "$CODEX_INSTALLER_URL" \
        CODEX_INSTALL_DIR="$bin_dir" CODEX_NON_INTERACTIVE=1 -- sh
    verify_tool codex "$bin_dir/codex"
}
