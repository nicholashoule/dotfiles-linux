#!/usr/bin/env bash
# Install Visual Studio Code and its code command from Microsoft's repository.
# Author: Nicholas Houle (https://github.com/nicholashoule)
#
# Usage: install-vscode.sh
#
# Adds Microsoft's VS Code package repository and its signing key, then installs
# the code package with dnf (Fedora, RHEL, and their relatives) or apt (Debian,
# Ubuntu, and their relatives). The package puts the code command in /usr/bin,
# and system updates keep it current; the package manager checks Microsoft's
# signature on every install and update. The key is downloaded to a file and
# must be a PGP public key before it is used. Only the system changes run with
# sudo (directly when run as root), and the package manager asks before it
# installs. Nothing happens when code is already on PATH, and an existing
# repository file, such as the one VS Code's Debian package adds, is left
# alone. It succeeds only when `code --version` runs afterward.
# INSTALL_VSCODE_ROOT, empty by default, prefixes the system paths (for testing).
# Exit status: 0 on success, 1 on failure, 2 for usage errors.
# https://code.visualstudio.com/docs/setup/linux
set -euo pipefail

# Global variables
readonly KEY_URL='https://packages.microsoft.com/keys/microsoft.asc'
readonly ROOT=${INSTALL_VSCODE_ROOT:-}
readonly RPM_REPO="$ROOT/etc/yum.repos.d/vscode.repo"
readonly APT_KEYRING="$ROOT/usr/share/keyrings/microsoft-vscode.asc"
readonly APT_SOURCES="$ROOT/etc/apt/sources.list.d/vscode.sources"
readonly APT_LIST="$ROOT/etc/apt/sources.list.d/vscode.list"
TMP_DIR=''

# die prints an error message and exits with status 1.
die() {
    printf 'install-vscode.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints how to run the helper.
usage() {
    printf 'Usage: install-vscode.sh\n'
    printf "Installs VS Code and its code command from Microsoft's repository with dnf\n"
    printf 'or apt, unless code is already on PATH.\n'
}

# cleanup removes the temporary directory if it exists.
cleanup() {
    if [[ -n $TMP_DIR && -d $TMP_DIR ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

# as_root COMMAND... runs COMMAND as root: directly when this already is root,
# otherwise with sudo.
as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# fetch_key downloads Microsoft's signing key to TMP_DIR/microsoft.asc and fails
# unless it is a PGP public key.
fetch_key() {
    local first
    curl --disable --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        --retry 3 --output "$TMP_DIR/microsoft.asc" "$KEY_URL" || die "could not download $KEY_URL"
    first=$(head -n 1 "$TMP_DIR/microsoft.asc")
    [[ $first == '-----BEGIN PGP PUBLIC KEY BLOCK-----'* ]] || die "the download from $KEY_URL is not a PGP public key"
}

# install_dnf adds the repository with its key, when it is missing, and installs
# code with dnf.
install_dnf() {
    if [[ ! -e $RPM_REPO ]]; then
        fetch_key
        as_root rpm --import "$TMP_DIR/microsoft.asc"
        printf '%s\n' '[code]' 'name=Visual Studio Code' 'baseurl=https://packages.microsoft.com/yumrepos/vscode' \
            'enabled=1' 'autorefresh=1' 'type=rpm-md' 'gpgcheck=1' "gpgkey=$KEY_URL" >"$TMP_DIR/vscode.repo"
        as_root install -D -m 0644 -- "$TMP_DIR/vscode.repo" "$RPM_REPO"
    fi
    as_root dnf install code
}

# install_apt adds the repository with its key, when neither it nor the one VS
# Code's package adds is there, and installs code with apt.
install_apt() {
    if [[ ! -e $APT_SOURCES && ! -e $APT_LIST ]]; then
        fetch_key
        as_root install -D -m 0644 -- "$TMP_DIR/microsoft.asc" "$APT_KEYRING"
        printf '%s\n' 'Types: deb' 'URIs: https://packages.microsoft.com/repos/code' 'Suites: stable' \
            'Components: main' 'Architectures: amd64,arm64,armhf' "Signed-By: ${APT_KEYRING#"$ROOT"}" \
            >"$TMP_DIR/vscode.sources"
        as_root install -D -m 0644 -- "$TMP_DIR/vscode.sources" "$APT_SOURCES"
    fi
    as_root apt-get update
    as_root apt-get install code
}

# main installs code with the package manager found, then checks that the code
# command runs.
main() {
    local tool
    if [[ ${1-} == -h || ${1-} == --help ]]; then
        usage
        return 0
    fi
    if [[ $# -gt 0 ]]; then
        usage >&2
        return 2
    fi
    if command -v code >/dev/null; then
        printf 'VS Code is already installed: %s\n' "$(command -v code)"
        return 0
    fi
    for tool in curl head mktemp; do
        command -v "$tool" >/dev/null || die "$tool is required"
    done
    if [[ $EUID -ne 0 ]]; then
        command -v sudo >/dev/null || die "sudo is required to add the repository and install the package"
    fi

    trap cleanup EXIT
    TMP_DIR=$(mktemp -d)
    if command -v dnf >/dev/null; then
        install_dnf
    elif command -v apt-get >/dev/null; then
        install_apt
    else
        die "no dnf or apt-get here; install VS Code from https://code.visualstudio.com/download"
    fi
    hash -r
    if ! command -v code >/dev/null || ! code --version >/dev/null; then
        die "the code command is not available after the install"
    fi
    printf 'Installed VS Code: %s\n' "$(command -v code)"
}
# Execute the main function with all command-line arguments.
main "$@"
