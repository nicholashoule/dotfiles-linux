#!/usr/bin/env bash
# Install a Go toolchain for the current user from go.dev.
# Author: Nicholas Houle (https://github.com/nicholashoule)
#
# Usage: install-go.sh [--latest | VERSION]
#
# By default, installs the newest patch of the release one behind the latest:
# the older of the two releases Go supports (go1.26.10 while go1.27 is current).
# --latest installs the newest release, and VERSION (1.26.10 or go1.26.10)
# picks any release. The archive's SHA-256 comes from go.dev's release list and
# must match before anything is unpacked. The toolchain goes in
# ~/.local/share/go (or GO_INSTALL_DIR), replacing an older one only after the
# new one runs, and go and gofmt are linked into ~/.local/bin, which leads PATH,
# so this toolchain wins over a distribution's /usr/bin/go. Running it again
# moves to a newer patch once there is one; a toolchain already at that version
# is left alone, a directory there that is not a Go toolchain is never
# replaced, and a go or gofmt in ~/.local/bin that is not one of these links is
# left alone with a warning. golang.sh turns Go's telemetry off.
# Exit status: 0 on success, 1 on failure, 2 for usage errors.
# https://go.dev/doc/install
set -euo pipefail

# Global variables
readonly DL_URL='https://go.dev/dl'
readonly VERSION_RE='^(go)?[0-9]+\.[0-9]+(\.[0-9]+)?$'
readonly INSTALL_DIR=${GO_INSTALL_DIR:-$HOME/.local/share/go}
readonly BIN_DIR="$HOME/.local/bin"
TMP_DIR=''

# die prints an error message and exits with status 1.
die() {
    printf 'install-go.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints how to run the helper.
usage() {
    printf 'Usage: install-go.sh [--latest | VERSION]\n'
    printf 'Installs Go into %s, linked from %s: the newest patch of\n' "$INSTALL_DIR" "$BIN_DIR"
    printf 'the release one behind the latest, the latest with --latest, or VERSION (such as 1.26.10).\n'
}

# cleanup removes the temporary directory, and an old toolchain moved into it.
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

# arch prints Go's name for this machine's CPU, or fails on one it has no Linux
# build for.
arch() {
    case $(uname -m) in
        x86_64 | amd64) printf 'amd64\n' ;;
        aarch64 | arm64) printf 'arm64\n' ;;
        armv6l | armv7l) printf 'armv6l\n' ;;
        i386 | i686) printf '386\n' ;;
        *) return 1 ;;
    esac
}

# release_versions LIST prints the release versions in go.dev's JSON LIST, newest
# first, once each.
release_versions() {
    grep -o '"version": *"go[0-9.]*"' "$1" | grep -o 'go[0-9.]*' | uniq
}

# release_sum LIST FILE prints the SHA-256 that LIST gives FILE, or fails.
release_sum() {
    local sum
    sum=$(awk -F'"' -v f="$2" '$2 == "filename" { found = ($4 == f) } found && $2 == "sha256" { print $4; exit }' "$1")
    [[ $sum =~ ^[0-9a-f]{64}$ ]] && printf '%s\n' "$sum"
}

# is_toolchain DIR succeeds when DIR holds a Go toolchain.
is_toolchain() {
    [[ -f $1/VERSION && -x $1/bin/go ]]
}

# link_tools links go and gofmt from BIN_DIR into INSTALL_DIR, replacing only
# links that already point into it or nowhere.
link_tools() {
    local tool link target
    mkdir -p -- "$BIN_DIR"
    for tool in go gofmt; do
        link="$BIN_DIR/$tool"
        if [[ -L $link ]]; then
            target=$(readlink -- "$link")
            if [[ $target != "$INSTALL_DIR/"* && -e $link ]]; then
                printf 'install-go.sh: left %s alone: it links to %s\n' "$link" "$target" >&2
                continue
            fi
        elif [[ -e $link ]]; then
            printf 'install-go.sh: left %s alone: it is not a link, and it shadows this toolchain\n' "$link" >&2
            continue
        fi
        ln -sfn -- "$INSTALL_DIR/bin/$tool" "$link"
    done
}

# main picks the version, downloads and checks the archive, unpacks it beside
# the install directory, swaps it in once it runs, and links the tools.
main() {
    local version=''
    local latest=false cpu list file expected actual tool
    local -a versions missing=()
    if [[ ${1-} == -h || ${1-} == --help ]]; then
        usage
        return 0
    fi
    if [[ $# -gt 1 ]] || [[ $# -eq 1 && $1 != --latest && ! $1 =~ $VERSION_RE ]]; then
        printf 'install-go.sh: %s is not --latest or a version such as 1.26.10\n' "$*" >&2
        usage >&2
        return 2
    fi
    if [[ ${1-} == --latest ]]; then
        latest=true
    elif [[ $# -eq 1 ]]; then
        version=go${1#go}
    fi
    for tool in awk curl grep sha256sum tar uname; do
        command -v "$tool" >/dev/null || missing+=("$tool")
    done
    [[ ${#missing[@]} -eq 0 ]] || die "missing ${missing[*]}; install them with your package manager"
    cpu=$(arch) || die "Go has no Linux build for this CPU ($(uname -m))"
    if [[ -e $INSTALL_DIR ]] && ! is_toolchain "$INSTALL_DIR"; then
        die "$INSTALL_DIR is not a Go toolchain; move it or set GO_INSTALL_DIR"
    fi

    mkdir -p -- "${INSTALL_DIR%/*}"
    trap cleanup EXIT
    # Beside the install directory, so the final swap is a rename.
    TMP_DIR=$(mktemp -d "${INSTALL_DIR%/*}/.go-install.XXXXXX")
    list="$TMP_DIR/releases.json"
    if [[ -n $version ]]; then
        fetch "$DL_URL/?mode=json&include=all" "$list" || die "could not download Go's release list"
    else
        fetch "$DL_URL/?mode=json" "$list" || die "could not download Go's release list"
        mapfile -t versions < <(release_versions "$list")
        [[ ${#versions[@]} -ge 2 ]] || die "Go's release list does not name two releases"
        version=${versions[1]}
        if [[ $latest == true ]]; then version=${versions[0]}; fi
    fi
    if is_toolchain "$INSTALL_DIR" && [[ $("$INSTALL_DIR/bin/go" env GOVERSION 2>/dev/null) == "$version" ]]; then
        link_tools
        printf '%s is already installed in %s.\n' "$version" "$INSTALL_DIR"
        return 0
    fi
    file="$version.linux-$cpu.tar.gz"
    expected=$(release_sum "$list" "$file") || die "Go's release list has no $file"
    fetch "$DL_URL/$file" "$TMP_DIR/$file" || die "could not download $DL_URL/$file"
    actual=$(sha256sum <"$TMP_DIR/$file")
    [[ ${actual%% *} == "$expected" ]] || die "$file does not match its checksum; nothing was installed"
    tar -xzf "$TMP_DIR/$file" -C "$TMP_DIR"
    [[ $("$TMP_DIR/go/bin/go" env GOVERSION 2>/dev/null) == "$version" ]] ||
        die "the unpacked go does not run as $version; nothing was installed"

    if [[ -e $INSTALL_DIR ]]; then
        mv -- "$INSTALL_DIR" "$TMP_DIR/old"
    fi
    if ! mv -- "$TMP_DIR/go" "$INSTALL_DIR"; then
        [[ ! -e $TMP_DIR/old ]] || mv -- "$TMP_DIR/old" "$INSTALL_DIR"
        die "could not move the new toolchain into $INSTALL_DIR"
    fi
    link_tools
    printf 'Installed %s in %s.\n' "$version" "$INSTALL_DIR"
}
# Execute the main function with all command-line arguments.
main "$@"
