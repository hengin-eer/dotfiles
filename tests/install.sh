#!/usr/bin/env bash
set -euo pipefail
DOTDIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT HUP INT TERM
CASE_NUMBER=0

fail() {
    printf 'not ok - %s\n' "$*" >&2
    if [ -n "${OUTPUT:-}" ] && [ -f "$OUTPUT" ]; then cat "$OUTPUT" >&2; fi
    exit 1
}
assert_file() { [ -f "$1" ] || fail "expected file: $1"; }
assert_contains() { grep -F "$2" "$1" >/dev/null || fail "expected '$2' in $1"; }

setup_case() {
    CASE_NUMBER=$((CASE_NUMBER + 1))
    CASE_ROOT="$TEST_ROOT/case-$CASE_NUMBER"
    REPO="$CASE_ROOT/repo"
    HOME_DIR="$CASE_ROOT/home"
    MOCK_BIN="$CASE_ROOT/mock-bin"
    OUTPUT="$CASE_ROOT/output"
    mkdir -p "$REPO/.bin" "$REPO/.config" "$REPO/.codex/rules" \
        "$REPO/.vim" "$REPO/fonts" "$HOME_DIR/.vim/autoload" "$MOCK_BIN"
    cp "$DOTDIR/.bin/install.sh" "$REPO/.bin/install.sh"
    cp "$DOTDIR/.bin/nvim-versions.tsv" "$REPO/.bin/nvim-versions.tsv"
    mkdir -p "$REPO/.config/shell" "$REPO/.config/nvim" "$REPO/.config/wezterm" \
        "$REPO/.config/herdr" "$REPO/.config/gh" "$REPO/.config/mdts" "$REPO/.config/mise"
    cat > "$REPO/.config/shell/path.sh" <<'EOF'
PATH="$HOME/.local/bin:$HOME/.bin:${TEST_BIN}:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH
EOF
    : > "$REPO/.config/nvim/init.lua"
    : > "$REPO/.config/wezterm/wezterm.lua"
    : > "$REPO/.config/herdr/config.toml"
    : > "$REPO/.config/gh/config.yml"
    : > "$REPO/.config/mdts/config.json"
    : > "$REPO/.config/mise/global.toml"
    for source in .bash_aliases .bash_profile .bashrc .zprofile .zshrc \
        .editorconfig .gitconfig_shared .vimrc .codex/AGENTS.md \
        .codex/rules/herdr-git.rules .bin/git-nlog .bin/git-ndiff; do
        mkdir -p "$REPO/$(dirname "$source")"
        : > "$REPO/$source"
    done
    cp "$DOTDIR/.codex/AGENTS.md" "$REPO/.codex/AGENTS.md"
    : > "$REPO/fonts/test.ttf"
    : > "$HOME_DIR/.vim/autoload/plug.vim"
    chmod +x "$REPO/.bin/install.sh"
    cat > "$MOCK_BIN/uname" <<'EOF'
#!/bin/sh
case "$1" in
    -s) printf '%s\n' "${TEST_OS:-Linux}" ;;
    -m) printf '%s\n' "${TEST_ARCH:-x86_64}" ;;
    *) printf '%s\n' "${TEST_OS:-Linux}" ;;
esac
EOF
    chmod +x "$MOCK_BIN/uname"
    export TEST_BIN="$MOCK_BIN" TEST_OS=Linux TEST_ARCH=x86_64
}

make_payload() {
    local package=$1 variant=${2:-regular} payload="$CASE_ROOT/payload" digest name
    rm -rf "$payload"
    mkdir -p "$payload/$package/bin" "$payload/$package/share/nvim/runtime/doc"
    cat > "$payload/$package/bin/nvim" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then printf 'NVIM v0.12.5\n'; exit 0; fi
if [ -n "${FAKE_NVIM_FAIL:-}" ]; then exit 1; fi
exit 0
EOF
    chmod +x "$payload/$package/bin/nvim"
    : > "$payload/$package/share/nvim/runtime/doc/options.txt"
    case "$variant" in
        extra) mkdir -p "$payload/other-app"; : > "$payload/other-app/state" ;;
        symlink) ln -s /tmp/outside "$payload/$package/bin/outside" ;;
    esac
    ARCHIVE="$CASE_ROOT/$package.tar.gz"
    if [ "$variant" = extra ]; then
        tar -czf "$ARCHIVE" -C "$payload" "$package" other-app
    else
        tar -czf "$ARCHIVE" -C "$payload" "$package"
    fi
    digest=$(shasum -a 256 "$ARCHIVE" 2>/dev/null | awk '{ print $1 }') ||
        digest=$(sha256sum "$ARCHIVE" | awk '{ print $1 }')
    : > "$REPO/.bin/nvim-versions.tsv"
    for name in nvim-macos-arm64 nvim-macos-x86_64 nvim-linux-arm64 nvim-linux-x86_64; do
        printf 'v0.12.5\t%s\t%s\n' "$name" "$digest" >> "$REPO/.bin/nvim-versions.tsv"
    done
}

run_installer() {
    HOME="$HOME_DIR" PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin" \
        TEST_BIN="$MOCK_BIN" TEST_OS="$TEST_OS" TEST_ARCH="$TEST_ARCH" \
        NVIM_ARCHIVE="${NVIM_ARCHIVE:-}" \
        "$REPO/.bin/install.sh" "$@" > "$OUTPUT" 2>&1
}
expect_failure() { if run_installer "$@"; then fail "expected installer failure: $*"; fi; }
assert_clean_staging() {
    if find "$HOME_DIR/.local/opt" -name '.nvim-install.*' -print 2>/dev/null | grep . >/dev/null; then
        fail "Neovim staging directory was left behind"
    fi
}

test_legacy_migration() {
    setup_case
    make_payload nvim-linux-x86_64
    printf 'shell state\n' > "$REPO/.config/shell/extra.conf"
    printf 'hidden state\n' > "$REPO/.config/shell/.private"
    printf 'mise state\n' > "$REPO/.config/mise/other.toml"
    printf 'herdr state\n' > "$REPO/.config/herdr/other.toml"
    printf 'auth state\n' > "$REPO/.config/gh/hosts.yml"
    ln -s "$REPO/.config" "$HOME_DIR/.config"
    NVIM_ARCHIVE="$ARCHIVE" run_installer
    assert_file "$REPO/.config/shell/path.sh"
    assert_file "$REPO/.config/mise/global.toml"
    assert_file "$REPO/.config/herdr/config.toml"
    assert_file "$HOME_DIR/.config/shell/extra.conf"
    assert_file "$HOME_DIR/.config/shell/.private"
    assert_file "$HOME_DIR/.config/mise/other.toml"
    assert_file "$HOME_DIR/.config/herdr/other.toml"
    assert_file "$HOME_DIR/.config/gh/hosts.yml"
    [ -L "$HOME_DIR/.config/shell/path.sh" ] || fail "managed path was not linked"
    printf 'ok - legacy .config migration preserves managed files and moves unmanaged state\n'
}

test_install_and_rerun() {
    setup_case
    make_payload nvim-linux-x86_64
    NVIM_ARCHIVE="$ARCHIVE" run_installer
    [ -x "$HOME_DIR/.local/opt/nvim-linux-x86_64/bin/nvim" ] || fail "Neovim was not installed"
    [ -L "$HOME_DIR/.local/bin/nvim" ] || fail "Neovim link was not created"
    assert_file "$HOME_DIR/.local/opt/nvim-linux-x86_64/share/nvim/runtime/doc/options.txt"
    assert_clean_staging
    run_installer
    assert_contains "$OUTPUT" "Neovim is available and compatible"
    printf 'ok - verified Neovim installation can be reused on rerun\n'
}

test_reject_bad_archives() {
    setup_case
    make_payload nvim-linux-x86_64
    printf 'changed archive\n' >> "$ARCHIVE"
    NVIM_ARCHIVE="$ARCHIVE"; export NVIM_ARCHIVE
    expect_failure
    assert_contains "$OUTPUT" "SHA-256 mismatch"
    [ ! -e "$HOME_DIR/.local/opt/nvim-linux-x86_64" ] || fail "checksum failure wrote final files"
    unset NVIM_ARCHIVE

    make_payload nvim-linux-x86_64 extra
    NVIM_ARCHIVE="$ARCHIVE"; export NVIM_ARCHIVE
    expect_failure
    assert_contains "$OUTPUT" "unexpected path in Neovim archive"
    make_payload nvim-linux-x86_64 symlink
    NVIM_ARCHIVE="$ARCHIVE"; export NVIM_ARCHIVE
    expect_failure
    assert_contains "$OUTPUT" "links and special files"
    [ ! -e "$HOME_DIR/.local/opt/nvim-linux-x86_64" ] || fail "rejected archive wrote final files"
    unset NVIM_ARCHIVE
    assert_clean_staging
    printf 'ok - checksum mismatches, unrelated paths, and links are rejected\n'
}

test_failed_extract_can_retry() {
    local real_tar broken_tar
    setup_case
    make_payload nvim-linux-x86_64
    real_tar=$(command -v tar)
    broken_tar="$MOCK_BIN/tar"
    cat > "$broken_tar" <<EOF
#!/bin/sh
if [ "\$1" = "-xzf" ]; then
    while [ "\$#" -gt 0 ]; do
        if [ "\$1" = "-C" ]; then
            mkdir -p "\$2/nvim-linux-x86_64/bin"
            : > "\$2/nvim-linux-x86_64/bin/partial"
            exit 9
        fi
        shift
    done
fi
exec "$real_tar" "\$@"
EOF
    chmod +x "$broken_tar"
    NVIM_ARCHIVE="$ARCHIVE"; export NVIM_ARCHIVE
    expect_failure
    assert_contains "$OUTPUT" "archive extraction failed"
    [ ! -e "$HOME_DIR/.local/opt/nvim-linux-x86_64" ] || fail "failed extraction wrote final files"
    assert_clean_staging
    rm "$broken_tar"
    run_installer
    [ -x "$HOME_DIR/.local/opt/nvim-linux-x86_64/bin/nvim" ] || fail "retry after failure failed"
    unset NVIM_ARCHIVE
    printf 'ok - failed extraction cleans staging and retry succeeds\n'
}

test_invalid_existing_and_partial() {
    setup_case
    cat > "$MOCK_BIN/nvim" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then exit 126; fi
exit 0
EOF
    chmod +x "$MOCK_BIN/nvim"
    expect_failure
    assert_contains "$OUTPUT" "Neovim cannot start"
    cat > "$MOCK_BIN/nvim" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then printf 'NVIM v0.10.0\n'; exit 0; fi
exit 0
EOF
    chmod +x "$MOCK_BIN/nvim"
    expect_failure
    assert_contains "$OUTPUT" "Neovim 0.11 or newer is required"
    cat > "$MOCK_BIN/nvim" <<'EOF'
#!/bin/sh
if [ "${1:-}" = "--version" ]; then printf 'NVIM v0.12.5\n'; exit 0; fi
exit 1
EOF
    expect_failure
    assert_contains "$OUTPUT" "API or runtime check failed"
    rm "$MOCK_BIN/nvim"
    mkdir -p "$HOME_DIR/.local/opt/nvim-linux-x86_64/lib"
    printf 'preserve me\n' > "$HOME_DIR/.local/opt/nvim-linux-x86_64/lib/state"
    expect_failure
    assert_contains "$OUTPUT" "incomplete Neovim installation"
    assert_contains "$HOME_DIR/.local/opt/nvim-linux-x86_64/lib/state" "preserve me"
    expect_failure --nvim-version v0.12.6
    assert_contains "$OUTPUT" "unsupported Neovim version"
    printf 'ok - old, broken, and partial Neovim installations fail safely\n'
}

test_dry_run_and_platforms() {
    local item os arch package
    setup_case
    mkdir -p "$HOME_DIR/.local/bin"
    ln -s "$HOME_DIR/.local/opt/nvim-linux-x86_64/bin/nvim" "$HOME_DIR/.local/bin/nvim"
    run_installer --dry-run
    if grep -F "Back up: $HOME_DIR/.local/bin/nvim" "$OUTPUT" >/dev/null; then
        fail "dry-run planned to back up a link to the future Neovim destination"
    fi
    assert_contains "$OUTPUT" "Already linked: $HOME_DIR/.local/bin/nvim"
    [ -L "$HOME_DIR/.local/bin/nvim" ] || fail "dry-run changed the planned Neovim link"
    [ ! -e "$HOME_DIR/.local/opt" ] || fail "dry-run created install directory"
    printf 'ok - dry-run recognizes a link to the planned Neovim path\n'

    setup_case
    mkdir -p "$HOME_DIR/.local/bin"
    ln -s "$HOME_DIR/missing-nvim" "$HOME_DIR/.local/bin/nvim"
    run_installer --dry-run
    assert_contains "$OUTPUT" "Back up: $HOME_DIR/.local/bin/nvim"
    assert_contains "$OUTPUT" "Download Neovim v0.12.5"
    [ -L "$HOME_DIR/.local/bin/nvim" ] || fail "dry-run changed the existing link"
    [ ! -e "$HOME_DIR/.local/opt" ] || fail "dry-run created install directory"
    printf 'ok - dry-run reports link backup without changing files\n'

    for item in 'Darwin arm64 nvim-macos-arm64' 'Darwin x86_64 nvim-macos-x86_64' \
        'Linux aarch64 nvim-linux-arm64' 'Linux x86_64 nvim-linux-x86_64'; do
        set -- $item
        os=$1
        arch=$2
        package=$3
        setup_case
        TEST_OS=$os TEST_ARCH=$arch run_installer --dry-run
        assert_contains "$OUTPUT" "$package"
    done
    printf 'ok - all supported OS and CPU combinations select the intended release\n'
}

test_legacy_migration
test_install_and_rerun
test_reject_bad_archives
test_failed_extract_can_retry
test_invalid_existing_and_partial
test_dry_run_and_platforms
