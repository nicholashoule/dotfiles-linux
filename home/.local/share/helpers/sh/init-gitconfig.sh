#!/usr/bin/env bash
# Create a starter ~/.gitconfig for personal Git settings, once.
#
# Usage: init-gitconfig.sh [--dry-run]
#
# ~/.gitconfig holds a machine's identity, signing key, and credential helpers,
# which must stay out of the public dotfiles repository, so it is created here
# instead of linked. Its existence also matters: `git config --global` (and tools
# such as `gh auth setup-git` that call it) writes to ~/.gitconfig when it exists,
# and otherwise to ~/.config/git/config, which links into the repository.
# An existing ~/.gitconfig, including a symlink, is never changed. The shared
# defaults stay in ~/.config/git/config, which Git reads first.
# Exit status: 0 when the file exists or was created, 1 on failure, 2 for usage errors.
set -euo pipefail

GITCONFIG=''

# die prints an error message and exits with status 1.
die() {
    printf 'init-gitconfig.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints the usage line and what the helper does.
usage() {
    printf 'Usage: init-gitconfig.sh [--dry-run]\n'
    printf 'Creates a starter ~/.gitconfig for identity, signing, and credential\n'
    printf 'helpers, unless one exists; --dry-run only reports what it would do.\n'
}

# write_starter FILE creates FILE with commented examples and no settings. noclobber
# makes the redirection fail, instead of replacing a file that appeared meanwhile.
write_starter() {
    set -o noclobber
    cat >"$1" <<'EOF'
# Personal Git settings for this machine: identity, commit signing, and
# credential helpers. Created once by the dotfiles' gitconfig setup step and
# never linked or overwritten, so nothing here reaches the public repository.
# `git config --global`, and tools such as `gh auth setup-git`, write here.
# Git reads the shared defaults in ~/.config/git/config first, so settings here win.
# https://git-scm.com/docs/git-config
#
# Identity:
#   git config --global user.name 'Your Name'
#   git config --global user.email you@example.com
#
# Commit signing with an SSH key (Git 2.34 or later):
#   git config --global gpg.format ssh
#   git config --global user.signingkey ~/.ssh/id_ed25519.pub
#   git config --global commit.gpgsign true
EOF
}

# main parses the arguments and creates ~/.gitconfig unless it exists.
main() {
    local dry_run=false
    case $# in
        0) ;;
        1)
            case $1 in
                --dry-run) dry_run=true ;;
                -h | --help)
                    usage
                    return 0
                    ;;
                *)
                    usage >&2
                    return 2
                    ;;
            esac
            ;;
        *)
            usage >&2
            return 2
            ;;
    esac
    [[ -n ${HOME-} && -d $HOME ]] || die "HOME is not set to a directory"
    GITCONFIG="$HOME/.gitconfig"

    if [[ -e $GITCONFIG || -L $GITCONFIG ]]; then
        printf '%s exists; leaving it unchanged.\n' "$GITCONFIG"
        return 0
    fi
    if [[ $dry_run == true ]]; then
        printf 'Would create %s.\n' "$GITCONFIG"
        return 0
    fi
    write_starter "$GITCONFIG" || die "could not create $GITCONFIG"
    printf 'Created %s. Set your identity with:\n' "$GITCONFIG"
    printf "  git config --global user.name 'Your Name'\n"
    printf '  git config --global user.email you@example.com\n'
}

main "$@"
