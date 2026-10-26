#!/usr/bin/env bash
# Install Oh My Posh for the current user from its GitHub release.
# Author: Nicholas Houle (https://github.com/nicholashoule)
#
# Usage: install-oh-my-posh.sh [VERSION]
#
# Downloads this machine's binary (posh-linux-amd64, -arm64, or -arm) and the
# release's checksums.txt, checks the binary's SHA-256 against it, and installs
# it as ~/.local/bin/oh-my-posh, which .bashrc puts on PATH. VERSION (31.9.1 or
# v31.9.1) picks a release; without it, the latest. The official install.sh
# skips the checksum and also fetches themes, which needs unzip; these dotfiles
# bring their own themes. The new binary replaces the old one with a rename, so
# a prompt running it meanwhile never sees half a file, and a binary that
# already matches is left alone. Then it turns on Oh My Posh's config
# auto-reload once; the setting persists, so shell startup does not repeat it.
# Nothing here edits shell startup files.
# Exit status: 0 on success, 1 on failure, 2 for usage errors.
# https://github.com/JanDeDobbeleer/oh-my-posh/releases
set -euo pipefail

# Global variables
readonly RELEASES_URL='https://github.com/JanDeDobbeleer/oh-my-posh/releases'
readonly BIN_DIR="$HOME/.local/bin"
readonly VERSION_RE='^v?[0-9]+\.[0-9]+\.[0-9]+$'
TMP_DIR=''

# die prints an error message and exits with status 1.
die() {
    printf 'install-oh-my-posh.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints how to run the helper.
usage() {
    printf 'Usage: install-oh-my-posh.sh [VERSION]\n'
    printf 'Installs Oh My Posh into %s from its GitHub release, the latest unless\n' "$BIN_DIR"
    printf 'VERSION (such as 31.9.1) says otherwise, after checking its SHA-256.\n'
}

# cleanup removes the temporary directory if it exists.
cleanup() {
    if [[ -n $TMP_DIR && -d $TMP_DIR ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

# fetch URL FILE downloads URL to FILE over HTTPS only, failing on HTTP errors.
fetch() {
    curl --disable --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        --retry 3 --output "$2" "$1"
}

# asset prints the release file name for this machine's CPU, or fails on a CPU
# that Oh My Posh has no Linux build for.
asset() {
    case $(uname -m) in
        x86_64 | amd64) printf 'posh-linux-amd64\n' ;;
        aarch64 | arm64) printf 'posh-linux-arm64\n' ;;
        armv6l | armv7l) printf 'posh-linux-arm\n' ;;
        *) return 1 ;;
    esac
}

# expected_sum CHECKSUMS NAME prints the SHA-256 that CHECKSUMS lists for NAME,
# or fails when it lists none.
expected_sum() {
    local sum name
    while read -r sum name; do
        if [[ $name == "$2" && $sum =~ ^[0-9a-f]{64}$ ]]; then
            printf '%s\n' "$sum"
            return 0
        fi
    done <"$1"
    return 1
}

# main checks the tools and the version, downloads the binary and the checksums,
# verifies the binary, installs it, and enables auto-reload.
main() {
    local version='' name base expected actual tool binary
    local -a missing=()
    if [[ ${1-} == -h || ${1-} == --help ]]; then
        usage
        return 0
    fi
    if [[ $# -gt 1 ]] || [[ $# -eq 1 && ! $1 =~ $VERSION_RE ]]; then
        printf 'install-oh-my-posh.sh: %s is not a version such as 31.9.1\n' "$*" >&2
        usage >&2
        return 2
    fi
    if [[ $# -eq 1 ]]; then
        version=v${1#v}
    fi
    for tool in curl sha256sum uname; do
        command -v "$tool" >/dev/null || missing+=("$tool")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "missing ${missing[*]}; install them with your package manager"
    name=$(asset) || die "Oh My Posh has no Linux build for this CPU ($(uname -m))"
    if [[ -n $version ]]; then
        base="$RELEASES_URL/download/$version"
    else
        base="$RELEASES_URL/latest/download"
    fi

    trap cleanup EXIT
    TMP_DIR=$(mktemp -d)
    binary="$TMP_DIR/$name"
    fetch "$base/checksums.txt" "$TMP_DIR/checksums.txt" || die "could not download $base/checksums.txt"
    expected=$(expected_sum "$TMP_DIR/checksums.txt" "$name") || die "$base/checksums.txt lists no checksum for $name"
    if [[ -x $BIN_DIR/oh-my-posh ]]; then
        actual=$(sha256sum <"$BIN_DIR/oh-my-posh")
        if [[ ${actual%% *} == "$expected" ]]; then
            printf 'Oh My Posh in %s is already %s.\n' "$BIN_DIR" "${version:-the latest release}"
            return 0
        fi
    fi
    fetch "$base/$name" "$binary" || die "could not download $base/$name"
    actual=$(sha256sum <"$binary")
    [[ ${actual%% *} == "$expected" ]] || die "$name does not match its checksum; nothing was installed"

    mkdir -p -- "$BIN_DIR"
    install -m 0755 -- "$binary" "$BIN_DIR/.oh-my-posh.new"
    mv -f -- "$BIN_DIR/.oh-my-posh.new" "$BIN_DIR/oh-my-posh"
    "$BIN_DIR/oh-my-posh" enable reload
    printf 'Installed Oh My Posh %s in %s.\n' "${version:-(latest)}" "$BIN_DIR"
}
# Execute the main function with all command-line arguments.
main "$@"
