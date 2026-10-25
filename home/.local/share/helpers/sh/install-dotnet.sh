#!/usr/bin/env bash
# Install a .NET SDK for the current user with Microsoft's dotnet-install script.
#
# Usage: install-dotnet.sh [DOTNET-INSTALL OPTION...]
#
# Installs into ~/.dotnet (or $DOTNET_INSTALL_DIR, or --install-dir DIR); without
# options that is the latest LTS SDK. Options pass through, for example
# `--channel 9.0` or `--dry-run`. A copy of dotnet-install.sh stays in the install
# directory for later installs.
# dotnet.sh puts ~/.dotnet on PATH; nothing here edits shell startup files.
# The package manager is the alternative: sudo dnf install dotnet-sdk-<version>.
# https://learn.microsoft.com/dotnet/core/tools/dotnet-install-script
set -euo pipefail

readonly INSTALL_URL='https://dot.net/v1/dotnet-install.sh'
INSTALL_DIR=${DOTNET_INSTALL_DIR:-$HOME/.dotnet}
TMP_DIR=''

# die prints an error message and exits with status 1.
die() {
    printf 'install-dotnet.sh: %s\n' "$1" >&2
    exit 1
}

# cleanup removes the temporary directory if it exists.
cleanup() {
    if [[ -n $TMP_DIR && -d $TMP_DIR ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

# main orchestrates the installation process. It handles command-line arguments,
# downloads the installer, and performs the installation.
main() {
    local installer i dry_run=false custom_dir=false
    local -a args=("$@")
    if [[ ${1-} == -h || ${1-} == --help ]]; then
        printf 'Usage: install-dotnet.sh [DOTNET-INSTALL OPTION...]\n'
        printf 'Installs the latest LTS .NET SDK into %s unless options say otherwise.\n' "$INSTALL_DIR"
        return 0
    fi
    # A directory given to dotnet-install (-i, --install-dir, -InstallDir) is used
    # for everything here too, so the SDK and the installer copy end up together.
    for ((i = 0; i < ${#args[@]}; i++)); do
        case ${args[i]} in
            --dry-run) dry_run=true ;;
            -i | --install-dir | -InstallDir)
                [[ -n ${args[i + 1]-} ]] || die "${args[i]} needs a directory"
                INSTALL_DIR=${args[i + 1]}
                custom_dir=true
                ;;
        esac
    done
    if [[ $custom_dir == false ]]; then
        args=(--install-dir "$INSTALL_DIR" "${args[@]}")
    fi
    command -v curl >/dev/null || die "curl is required"

    trap cleanup EXIT
    TMP_DIR=$(mktemp -d)
    installer="$TMP_DIR/dotnet-install.sh"
    curl --disable --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        --output "$installer" "$INSTALL_URL" || die "could not download $INSTALL_URL"

    # A dry run only prints what dotnet-install would download, so it changes nothing.
    if [[ $dry_run == true ]]; then
        bash "$installer" "${args[@]}"
        return
    fi
    mkdir -p -- "$INSTALL_DIR"
    bash "$installer" "${args[@]}"
    install -m 0755 -- "$installer" "$INSTALL_DIR/dotnet-install.sh"
}
# Execute the main function with all command-line arguments.
main "$@"
