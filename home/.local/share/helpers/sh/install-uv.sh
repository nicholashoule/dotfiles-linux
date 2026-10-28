#!/usr/bin/env bash
# Install uv, the Python package and project manager, for the current user from
# its GitHub release.
# Author: Nicholas Houle (https://github.com/nicholashoule)
#
# Usage: install-uv.sh [VERSION]
#
# Downloads this machine's archive (uv-x86_64-unknown-linux-gnu.tar.gz and the
# like, the glibc build) and its .sha256 file, checks the archive against it,
# and installs uv and uvx into ~/.local/bin, which .bashrc puts on PATH. VERSION
# (0.13.6 or v0.13.6) picks a release; without it, the latest, named by the
# GitHub release API. The official install script is a download piped into a
# shell, skips the checksum, and offers to edit .bashrc; this helper downloads
# to a file first and never edits shell startup files. The unpacked uv must
# report the version before anything is installed; each new binary replaces the
# old one with a rename, so a shell running it meanwhile never sees half a file,
# and a uv already at that version is left alone. python.sh loads uv's
# completion.
# Exit status: 0 on success, 1 on failure, 2 for usage errors.
# https://github.com/astral-sh/uv/releases
set -euo pipefail

# Global variables
readonly RELEASES_URL='https://github.com/astral-sh/uv/releases'
readonly LATEST_URL='https://api.github.com/repos/astral-sh/uv/releases/latest'
readonly BIN_DIR="$HOME/.local/bin"
readonly VERSION_RE='^v?[0-9]+\.[0-9]+\.[0-9]+$'
TMP_DIR=''

# die prints an error message and exits with status 1.
die() {
    printf 'install-uv.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints how to run the helper.
usage() {
    printf 'Usage: install-uv.sh [VERSION]\n'
    printf 'Installs uv and uvx into %s from a GitHub release, the latest unless\n' "$BIN_DIR"
    printf 'VERSION (such as 0.13.6) says otherwise, after checking the SHA-256.\n'
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

# target prints the release's name for this machine's CPU and glibc, or fails
# on a CPU that uv has no Linux build for.
target() {
    case $(uname -m) in
        x86_64 | amd64) printf 'uv-x86_64-unknown-linux-gnu\n' ;;
        aarch64 | arm64) printf 'uv-aarch64-unknown-linux-gnu\n' ;;
        armv7l) printf 'uv-armv7-unknown-linux-gnueabihf\n' ;;
        i386 | i686) printf 'uv-i686-unknown-linux-gnu\n' ;;
        ppc64le) printf 'uv-powerpc64le-unknown-linux-gnu\n' ;;
        riscv64) printf 'uv-riscv64gc-unknown-linux-gnu\n' ;;
        s390x) printf 'uv-s390x-unknown-linux-gnu\n' ;;
        *) return 1 ;;
    esac
}

# latest_version RELEASE prints the tag named in RELEASE, the API's JSON for the
# latest release, or fails when it names none.
latest_version() {
    local tag
    tag=$(grep -o '"tag_name": *"[^"]*"' "$1" | head -n 1 | grep -o '"[^"]*"$') || return 1
    tag=${tag//\"/}
    [[ $tag =~ $VERSION_RE ]] && printf '%s\n' "${tag#v}"
}

# expected_sum CHECKSUM NAME prints the SHA-256 that the CHECKSUM file gives
# NAME, or fails when it is for another file or malformed.
expected_sum() {
    local sum name
    read -r sum name <"$1" || true
    [[ $name == "$2" && $sum =~ ^[0-9a-f]{64}$ ]] && printf '%s\n' "$sum"
}

# installed_version prints the version of the uv in BIN_DIR, or nothing.
installed_version() {
    local line
    line=$("$BIN_DIR/uv" --version 2>/dev/null) || return 0
    line=${line#uv }
    printf '%s\n' "${line%% *}"
}

# main checks the tools and the version, downloads the checksum and the archive,
# verifies and unpacks the archive, and installs uv and uvx.
main() {
    local version='' name file base expected actual tool
    local -a missing=()
    if [[ ${1-} == -h || ${1-} == --help ]]; then
        usage
        return 0
    fi
    if [[ $# -gt 1 ]] || [[ $# -eq 1 && ! $1 =~ $VERSION_RE ]]; then
        printf 'install-uv.sh: %s is not a version such as 0.13.6\n' "$*" >&2
        usage >&2
        return 2
    fi
    if [[ $# -eq 1 ]]; then
        version=${1#v}
    fi
    for tool in curl grep sha256sum tar uname; do
        command -v "$tool" >/dev/null || missing+=("$tool")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "missing ${missing[*]}; install them with your package manager"
    name=$(target) || die "uv has no Linux build for this CPU ($(uname -m))"

    trap cleanup EXIT
    TMP_DIR=$(mktemp -d)
    if [[ -z $version ]]; then
        fetch "$LATEST_URL" "$TMP_DIR/latest.json" || die "could not download $LATEST_URL"
        version=$(latest_version "$TMP_DIR/latest.json") || die "$LATEST_URL names no release"
    fi
    if [[ -x $BIN_DIR/uv && $(installed_version) == "$version" ]]; then
        printf 'uv %s is already installed in %s.\n' "$version" "$BIN_DIR"
        return 0
    fi
    base="$RELEASES_URL/download/$version"
    file="$name.tar.gz"
    fetch "$base/$file.sha256" "$TMP_DIR/$file.sha256" || die "could not download $base/$file.sha256"
    expected=$(expected_sum "$TMP_DIR/$file.sha256" "$file") || die "$base/$file.sha256 lists no checksum for $file"
    fetch "$base/$file" "$TMP_DIR/$file" || die "could not download $base/$file"
    actual=$(sha256sum <"$TMP_DIR/$file")
    [[ ${actual%% *} == "$expected" ]] || die "$file does not match its checksum; nothing was installed"
    tar -xzf "$TMP_DIR/$file" -C "$TMP_DIR"
    [[ -x $TMP_DIR/$name/uv && -x $TMP_DIR/$name/uvx ]] || die "$file holds no uv and uvx; nothing was installed"
    [[ $("$TMP_DIR/$name/uv" --version 2>/dev/null) == "uv $version"* ]] ||
        die "the unpacked uv does not run as $version; nothing was installed"

    mkdir -p -- "$BIN_DIR"
    for tool in uv uvx; do
        install -m 0755 -- "$TMP_DIR/$name/$tool" "$BIN_DIR/.$tool.new"
        mv -f -- "$BIN_DIR/.$tool.new" "$BIN_DIR/$tool"
    done
    printf 'Installed uv %s in %s.\n' "$version" "$BIN_DIR"
}
# Execute the main function with all command-line arguments.
main "$@"
