#!/usr/bin/env bash
# Install Oh My Posh for the current user with its official installer.
#
# Usage: install-oh-my-posh.sh
#
# Downloads https://ohmyposh.dev/install.sh to a file, checks that it is a
# script, and runs it to install into ~/.local/bin, which .bashrc puts on PATH.
# The installer refuses a -d directory that does not exist, so this creates it.
# Then it turns on Oh My Posh's config auto-reload once; the setting persists,
# so shell startup does not repeat it. Nothing here edits shell startup files.
set -euo pipefail

readonly INSTALL_URL='https://ohmyposh.dev/install.sh'
readonly BIN_DIR="$HOME/.local/bin"
TMP_DIR=''

# die prints an error message and exits with status 1.
die() {
    printf 'install-oh-my-posh.sh: %s\n' "$1" >&2
    exit 1
}

# cleanup removes the temporary directory if it exists.
cleanup() {
    if [[ -n $TMP_DIR && -d $TMP_DIR ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

# main downloads the installer, runs it into BIN_DIR, and enables auto-reload.
main() {
    local installer
    if [[ ${1-} == -h || ${1-} == --help ]]; then
        printf 'Usage: install-oh-my-posh.sh\n'
        printf 'Installs Oh My Posh into %s and turns on config auto-reload.\n' "$BIN_DIR"
        return 0
    fi
    [[ $# -eq 0 ]] || die "unexpected arguments: $*"
    command -v curl >/dev/null || die "curl is required"

    trap cleanup EXIT
    TMP_DIR=$(mktemp -d)
    installer="$TMP_DIR/install.sh"
    # A file, not a pipe into bash: a failed or cut-off download stops here
    # instead of running nothing, or half a script, and reporting success.
    curl --disable --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        --output "$installer" "$INSTALL_URL" || die "could not download $INSTALL_URL"
    [[ $(head -c 2 "$installer") == '#!' ]] || die "the download from $INSTALL_URL is not a script"

    mkdir -p -- "$BIN_DIR"
    bash "$installer" -d "$BIN_DIR"
    "$BIN_DIR/oh-my-posh" enable reload
}
# Execute the main function with all command-line arguments.
main "$@"
