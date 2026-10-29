#!/usr/bin/env bash
# Create the starter ~/.bashrc.d/local.sh, for this machine's own settings.
# Author: Nicholas Houle (https://github.com/nicholashoule)
#
# Usage: init-local.sh [--dry-run] [--force]
#
# .bashrc sources every file in ~/.bashrc.d, and local.sh is the one there for
# settings that belong to this machine only, so it is created here instead of
# linked from the public dotfiles repository. The starter holds only comments:
# examples of the overrides the dotfiles support, to uncomment. It is readable
# only by you, because such settings sometimes end up holding tokens.
# An existing local.sh, including a symlink, is left unchanged unless --force is
# given; then it is renamed to local.sh.bak.DATE-TIME first. ~/.bashrc.d must be
# a real directory, because a symlinked one could lead into the repository.
# Exit status: 0 when the file exists or was created, 1 on failure, 2 for usage errors.
set -euo pipefail

# Global variables
LOCAL_DIR=''
LOCAL_FILE=''

# die prints an error message and exits with status 1.
die() {
    printf 'init-local.sh: %s\n' "$1" >&2
    exit 1
}

# usage prints the usage line and what the helper does.
usage() {
    printf 'Usage: init-local.sh [--dry-run] [--force]\n'
    printf 'Creates ~/.bashrc.d/local.sh, with commented examples of settings for this\n'
    printf 'machine only, unless one exists. --force backs up an existing one and\n'
    printf 'replaces it; --dry-run only reports what would happen.\n'
}

# starter prints the starter file: comments only, so it changes nothing until
# you uncomment a line. It shows only what belongs here; settings that do not,
# such as Go's (go env -w) or credentials (each tool's own files), are left out
# rather than explained.
starter() {
    cat <<'EOF'
# shellcheck shell=bash
# Settings for this machine only. .bashrc sources this file with ~/.bashrc.d;
# the dotfiles created it once and never link it. Uncomment what you need.

# Prompt theme: a theme in ~/.config/oh-my-posh/themes, or a theme file's path.
# OHMYPOSH_THEME=bubbles

# Completion list colors (mi colors subcommands and options).
# LS_COLORS+=':mi=00;36'

# AWS region and profile.
# export AWS_REGION=eu-west-1 AWS_DEFAULT_REGION=eu-west-1
# export AWS_PROFILE=work

# Kubeconfig files, merged in order.
# export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/work

# History size.
# HISTSIZE=100000 HISTFILESIZE=200000

# A directory first on PATH, added once.
# case ":$PATH:" in *":$HOME/opt/tool/bin:"*) ;; *) PATH="$HOME/opt/tool/bin:$PATH" ;; esac

# Aliases.
# alias proj='cd ~/projects'
EOF
}

# write_starter FILE creates FILE from starter, readable only by you. noclobber
# makes the redirection fail, instead of replacing a file that appeared meanwhile.
write_starter() {
    umask 077
    set -o noclobber
    starter >"$1"
}

# backup_path prints an unused backup name for local.sh:
# local.sh.bak.YYYYMMDD-HHMMSS, with .N added when that is taken.
backup_path() {
    local base path n=0
    base="$LOCAL_FILE.bak.$(date +%Y%m%d-%H%M%S)"
    path=$base
    while [[ -e $path || -L $path ]]; do
        n=$((n + 1))
        path="$base.$n"
    done
    printf '%s\n' "$path"
}

# main parses the arguments, backs up an existing local.sh when --force asks to
# replace it, and creates the starter unless one exists.
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
    LOCAL_DIR="$HOME/.bashrc.d"
    LOCAL_FILE="$LOCAL_DIR/local.sh"
    if [[ -L $LOCAL_DIR ]]; then
        die "$LOCAL_DIR is a symlink; local.sh belongs in a real directory, outside the repository"
    fi
    if [[ -e $LOCAL_DIR && ! -d $LOCAL_DIR ]]; then
        die "$LOCAL_DIR is not a directory"
    fi

    if [[ -e $LOCAL_FILE || -L $LOCAL_FILE ]]; then
        if [[ $force == false ]]; then
            printf '%s exists; leaving it unchanged (--force backs it up and replaces it).\n' "$LOCAL_FILE"
            return 0
        fi
        backup=$(backup_path)
    fi
    if [[ $dry_run == true ]]; then
        if [[ -n $backup ]]; then
            printf 'Would move %s to %s.\n' "$LOCAL_FILE" "$backup"
        fi
        printf 'Would create %s.\n' "$LOCAL_FILE"
        return 0
    fi
    mkdir -p -- "$LOCAL_DIR" || die "could not create $LOCAL_DIR"
    # A rename, not a copy: a symlink is kept as a symlink, and the new file is
    # never written through it into whatever it points to.
    if [[ -n $backup ]]; then
        mv -- "$LOCAL_FILE" "$backup" || die "could not move $LOCAL_FILE to $backup"
        printf 'Moved %s to %s.\n' "$LOCAL_FILE" "$backup"
    fi
    write_starter "$LOCAL_FILE" || die "could not create $LOCAL_FILE${backup:+; the old one is $backup}"
    printf 'Created %s with commented examples; uncomment what this machine needs.\n' "$LOCAL_FILE"
}

main "$@"
