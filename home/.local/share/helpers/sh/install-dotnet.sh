#!/usr/bin/env bash
# Install a .NET SDK for the current user with Microsoft's dotnet-install script.
# Author: Nicholas Houle (https://github.com/nicholashoule)
#
# Usage: install-dotnet.sh [RELEASE | VERSION] [DOTNET-INSTALL OPTION...]
#
# Installs into ~/.dotnet (or $DOTNET_INSTALL_DIR, or -i/--install-dir DIR). The
# optional first argument picks what to install, as a shorthand for
# dotnet-install's --channel or --version: LTS or STS, a release such as 10.0
# (or just 10), a feature band such as 10.0.1xx, or an exact SDK version such as
# 10.0.100. Without it, that is the latest LTS SDK. Other options pass through,
# for example `--runtime aspnetcore` or `--dry-run`. A copy of dotnet-install.sh
# stays in the install directory for later installs.
# dotnet.sh puts ~/.dotnet on PATH; nothing here edits shell startup files.
# The package manager is the alternative: sudo dnf install dotnet-sdk-<version>.
# Exit status: 0 on success, 1 on failure, 2 for usage errors.
# https://learn.microsoft.com/dotnet/core/tools/dotnet-install-script
set -euo pipefail

# Global variables
readonly INSTALL_URL='https://dot.net/v1/dotnet-install.sh'
# The forms of the first argument: a major version becomes a release (10 is
# 10.0); LTS, STS, a release, or a feature band is a channel; the rest is an
# exact version, with a preview suffix allowed (10.0.100-rc.2.25502.107).
readonly MAJOR_RE='^[0-9]+$'
readonly CHANNEL_RE='^([Ll][Tt][Ss]|[Ss][Tt][Ss]|[0-9]+\.[0-9]+(\.[0-9]xx)?)$'
readonly VERSION_RE='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
INSTALL_DIR=${DOTNET_INSTALL_DIR:-$HOME/.dotnet}
TMP_DIR=''

# die prints an error message and exits with status 1.
die() {
    printf 'install-dotnet.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints how to run the helper.
usage() {
    printf 'Usage: install-dotnet.sh [RELEASE | VERSION] [DOTNET-INSTALL OPTION...]\n'
    printf 'Installs a .NET SDK into %s: the latest LTS release unless RELEASE\n' "$INSTALL_DIR"
    printf 'or VERSION says otherwise.\n'
    printf '  RELEASE  LTS, STS, a release such as 10.0 (or 10), or a feature band such as 10.0.1xx\n'
    printf '  VERSION  an exact SDK version, such as 10.0.100\n'
    printf 'Other options pass through to dotnet-install.sh, for example --dry-run:\n'
    printf '  https://learn.microsoft.com/dotnet/core/tools/dotnet-install-script\n'
}

# usage_error MESSAGE prints MESSAGE and the usage, and exits with status 2.
usage_error() {
    printf 'install-dotnet.sh: %s\n' "$1" >&2
    usage >&2
    exit 2
}

# cleanup removes the temporary directory if it exists.
cleanup() {
    if [[ -n $TMP_DIR && -d $TMP_DIR ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

# main turns the optional release or version into dotnet-install's option,
# checks the other options, downloads the installer to a file, checks it, and
# installs the SDK.
main() {
    local installer i release='' dry_run=false custom_dir=false
    local -a args selector=()
    if [[ ${1-} == -h || ${1-} == --help ]]; then
        usage
        return 0
    fi
    if [[ $# -gt 0 && $1 != -* ]]; then
        release=$1
        shift
        if [[ $release =~ $MAJOR_RE ]]; then
            selector=(--channel "$release.0")
        elif [[ $release =~ $CHANNEL_RE ]]; then
            selector=(--channel "$release")
        elif [[ $release =~ $VERSION_RE ]]; then
            selector=(--version "$release")
        else
            usage_error "$release is not a release or version"
        fi
    fi
    args=("$@")
    # A directory given to dotnet-install (-i, --install-dir, -InstallDir) is used
    # for everything here too, so the SDK and the installer copy end up together.
    for ((i = 0; i < ${#args[@]}; i++)); do
        case ${args[i]} in
            --dry-run) dry_run=true ;;
            -i | --install-dir | -[Ii]nstall[Dd]ir)
                [[ -n ${args[i + 1]-} ]] || usage_error "${args[i]} needs a directory"
                INSTALL_DIR=${args[i + 1]}
                custom_dir=true
                ;;
            -c | --channel | -[Cc]hannel | -v | --version | -[Vv]ersion)
                [[ -z $release ]] || usage_error "give $release or ${args[i]}, not both"
                ;;
        esac
    done
    args=("${selector[@]}" "${args[@]}")
    if [[ $custom_dir == false ]]; then
        args=(--install-dir "$INSTALL_DIR" "${args[@]}")
    fi
    command -v curl >/dev/null || die "curl is required"

    trap cleanup EXIT
    TMP_DIR=$(mktemp -d)
    installer="$TMP_DIR/dotnet-install.sh"
    # A file, not a pipe into bash: a failed or cut-off download stops here
    # instead of running nothing, or half a script, and reporting success.
    curl --disable --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
        --output "$installer" "$INSTALL_URL" || die "could not download $INSTALL_URL"
    [[ $(head -c 2 "$installer") == '#!' ]] || die "the download from $INSTALL_URL is not a script"

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
