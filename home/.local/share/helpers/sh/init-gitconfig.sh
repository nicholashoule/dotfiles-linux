#!/usr/bin/env bash
# Create a starter ~/.gitconfig for personal Git settings.
# Author: Nicholas Houle (https://github.com/nicholashoule)
#
# Usage: init-gitconfig.sh [--dry-run] [--force]
#
# ~/.gitconfig holds a machine's identity, signing key, and credential helpers,
# which must stay out of the public dotfiles repository, so it is created here
# instead of linked. Its existence also matters: `git config --global` (and tools
# such as `gh auth setup-git` that call it) writes to ~/.gitconfig when it exists,
# and otherwise to ~/.config/git/config, which links into the repository. Git
# reads both, ~/.config/git/config first, so the starter needs no include.
# The starter turns on what this machine is ready for: commit signing when gpg
# has a usable secret key, and HTTPS credentials from the GitHub CLI (github.com
# and gist.github.com) and the GitLab CLI (gitlab.com) when each is installed.
# Anything else is a comment naming the command that turns it on.
# An existing ~/.gitconfig, including a symlink, is left unchanged unless --force
# is given; then it is renamed to ~/.gitconfig.bak.DATE-TIME first.
# Exit status: 0 when the file exists or was created, 1 on failure, 2 for usage errors.
set -euo pipefail

# Global variables
GITCONFIG=''
GPG=''  # gpg's command when it has a usable secret key
GH=''   # gh's command when it is installed
GLAB='' # glab's command when it is installed

# die prints an error message and exits with status 1.
die() {
    printf 'init-gitconfig.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints the usage line and what the helper does.
usage() {
    printf 'Usage: init-gitconfig.sh [--dry-run] [--force]\n'
    printf 'Creates a starter ~/.gitconfig for identity, signing, and credential\n'
    printf 'helpers, unless one exists. --force backs up an existing one and replaces\n'
    printf 'it; --dry-run only reports what would happen.\n'
}

# tool_command NAME prints the command to run NAME, or fails when it is not
# installed. That is NAME's absolute path, as gh and glab write it themselves, so
# Git finds it without the login shell's PATH, unless the path has characters
# that would need quoting in a Git config value or a shell command.
tool_command() {
    local path
    path=$(command -v "$1") || return 1
    if [[ $path =~ ^/[[:alnum:]/._+-]+$ ]]; then
        printf '%s\n' "$path"
    else
        printf '%s\n' "$1"
    fi
}

# has_secret_key GPG succeeds when GPG lists a secret key that it does not mark
# invalid, disabled, revoked, expired, or not valid. Without a GnuPG home there
# is no key, and asking gpg would create one, so it is not asked.
has_secret_key() {
    [[ -d ${GNUPGHOME:-$HOME/.gnupg} ]] || return 1
    { "$1" --batch --list-secret-keys --with-colons 2>/dev/null || true; } |
        awk -F: '$1 == "sec" && $2 !~ /[idren]/ { found = 1 } END { exit !found }'
}

# detect_tools sets GPG, GH, and GLAB to the commands the starter turns on.
detect_tools() {
    local gpg
    if gpg=$(tool_command gpg) && has_secret_key "$gpg"; then
        GPG=$gpg
    fi
    GH=$(tool_command gh) || GH=''
    GLAB=$(tool_command glab) || GLAB=''
}

# credential_section URL COMMAND prints a section that makes the CLI COMMAND the
# only credential helper for URL. The empty helper clears helpers set earlier,
# such as a system-wide one, for that host only.
credential_section() {
    printf '[credential "%s"]\n\thelper =\n\thelper = !%s auth git-credential\n' "$1" "$2"
}

# starter prints the starter file: commented examples, and the signing and
# credential settings this machine is ready for.
starter() {
    cat <<'EOF'
# Personal Git settings for this machine: identity, commit signing, and
# credential helpers. Created by the dotfiles' gitconfig setup step and never
# linked, so nothing here reaches the public repository.
# `git config --global`, and tools such as `gh auth setup-git`, write here.
# Git reads the shared defaults in ~/.config/git/config first, so settings here
# win, and no include is needed.
# https://git-scm.com/docs/git-config
#
# Identity:
#   git config --global user.name 'Your Name'
#   git config --global user.email you@example.com

EOF
    if [[ -n $GPG ]]; then
        printf '# Commit signing with GnuPG, with the key for user.email or user.signingkey.\n'
        printf '[commit]\n\tgpgsign = true\n[gpg]\n\tprogram = %s\n' "$GPG"
    else
        cat <<'EOF'
# Commit signing with GnuPG, once `gpg --list-secret-keys` shows a key; Git
# signs with the key for user.email, or user.signingkey:
#   git config --global commit.gpgsign true
EOF
    fi
    cat <<'EOF'
#
# Or commit signing with an SSH key (Git 2.34 or later):
#   git config --global gpg.format ssh
#   git config --global user.signingkey ~/.ssh/id_ed25519.pub
#   git config --global commit.gpgsign true

EOF
    if [[ -n $GH ]]; then
        cat <<'EOF'
# HTTPS credentials for GitHub and its gists from the GitHub CLI, as
# `gh auth setup-git` writes them.
EOF
        credential_section https://github.com "$GH"
        credential_section https://gist.github.com "$GH"
    else
        cat <<'EOF'
# HTTPS credentials for GitHub and its gists from the GitHub CLI: install gh,
# then run `gh auth login`, or `gh auth setup-git` when already logged in.
EOF
    fi
    printf '\n'
    if [[ -n $GLAB ]]; then
        cat <<'EOF'
# HTTPS credentials for GitLab from the GitLab CLI, as
# `glab auth login --setup-git-credential-helper` writes them.
EOF
        credential_section https://gitlab.com "$GLAB"
    else
        cat <<'EOF'
# HTTPS credentials for GitLab from the GitLab CLI: install glab, then run
# `glab auth login --hostname gitlab.com --setup-git-credential-helper`.
EOF
    fi
}

# write_starter FILE creates FILE from starter. noclobber makes the redirection
# fail, instead of replacing a file that appeared meanwhile.
write_starter() {
    set -o noclobber
    starter >"$1"
}

# report prints which of the starter's settings are on, and why the others are off.
report() {
    if [[ -n $GPG ]]; then
        printf '  commit signing (%s): on\n' "$GPG"
    else
        printf '  commit signing: off until gpg has a secret key\n'
    fi
    if [[ -n $GH ]]; then
        printf '  github.com and gist.github.com credentials (%s): on\n' "$GH"
    else
        printf '  github.com and gist.github.com credentials: off; gh is not installed\n'
    fi
    if [[ -n $GLAB ]]; then
        printf '  gitlab.com credentials (%s): on\n' "$GLAB"
    else
        printf '  gitlab.com credentials: off; glab is not installed\n'
    fi
}

# backup_path prints an unused backup name for ~/.gitconfig:
# ~/.gitconfig.bak.YYYYMMDD-HHMMSS, with .N added when that is taken.
backup_path() {
    local base path n=0
    base="$GITCONFIG.bak.$(date +%Y%m%d-%H%M%S)"
    path=$base
    while [[ -e $path || -L $path ]]; do
        n=$((n + 1))
        path="$base.$n"
    done
    printf '%s\n' "$path"
}

# main parses the arguments, backs up an existing ~/.gitconfig when --force asks
# to replace it, and creates the starter unless one exists.
main() {
    local arg dry_run=false force=false backup=''
    for arg in "$@"; do
        case $arg in
            --dry-run) dry_run=true ;;
            --force) force=true ;;
            -h | --help)
                usage
                return 0
                ;;
            *)
                usage >&2
                return 2
                ;;
        esac
    done
    [[ -n ${HOME-} && -d $HOME ]] || die "HOME is not set to a directory"
    GITCONFIG="$HOME/.gitconfig"

    if [[ -e $GITCONFIG || -L $GITCONFIG ]]; then
        if [[ $force == false ]]; then
            printf '%s exists; leaving it unchanged (--force backs it up and replaces it).\n' "$GITCONFIG"
            return 0
        fi
        backup=$(backup_path)
    fi
    detect_tools
    if [[ $dry_run == true ]]; then
        if [[ -n $backup ]]; then
            printf 'Would move %s to %s.\n' "$GITCONFIG" "$backup"
        fi
        printf 'Would create %s with:\n' "$GITCONFIG"
        report
        return 0
    fi
    # A rename, not a copy: a symlink is kept as a symlink, and the new file is
    # never written through it into whatever it points to.
    if [[ -n $backup ]]; then
        mv -- "$GITCONFIG" "$backup" || die "could not move $GITCONFIG to $backup"
        printf 'Moved %s to %s.\n' "$GITCONFIG" "$backup"
    fi
    write_starter "$GITCONFIG" || die "could not create $GITCONFIG${backup:+; the old one is $backup}"
    printf 'Created %s with:\n' "$GITCONFIG"
    report
    printf 'Set your identity with:\n'
    printf "  git config --global user.name 'Your Name'\n"
    printf '  git config --global user.email you@example.com\n'
}
# Invoke the main function with all script arguments.
main "$@"
