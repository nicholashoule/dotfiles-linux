# shellcheck shell=bash
# .bashrc
#
# Interactive shell setup. Bash reads this for interactive non-login shells, such
# as new terminal windows on Linux; login shells reach it through ~/.bash_profile.
# Scripts do not read it, but programs launched from the shell inherit its exports.
#
# Order of operations:
#   1. /etc/bashrc     system defaults, first so everything below can override them
#   2. environment     ~/.local/bin and ~/bin lead PATH so user tools win, and
#                      the helpers in ~/.local/share/helpers/sh go last;
#                      DO_NOT_TRACK opts out of telemetry
#   3. completion      completion list colors, then bash-completion for
#                      interactive shells, unless step 1 already loaded it, so
#                      every snippet can register its own
#   4. ~/.bashrc.d/*   one file per tool, sourced in glob (alphabetical) order;
#                      prefix a name with 00- or zz- to run it first or last.
#                      Machine-specific settings go in ~/.bashrc.d/local.sh,
#                      which the local setup step creates with commented
#                      examples and never links; it loads with the others.
#
# Startup cost: this runs for every new shell, so keep it fast.
#   - PATH edits skip entries already present, so re-sourcing this file or
#     nesting shells does not grow PATH.
#   - Snippets skip missing tools via `command -v` and load completions and the
#     prompt only in interactive shells.
#   - Each command substitution (go env, completion generators, prompt init)
#     starts a process; measure the total with: time bash -i -c exit

# Source global definitions
if [ -f /etc/bashrc ]; then
    # shellcheck source=/dev/null
    . /etc/bashrc
fi

# User specific environment
# Each entry is prepended in turn, leaving ~/.local/bin ahead of ~/bin.
for user_bin in "$HOME/bin" "$HOME/.local/bin"; do
    case ":$PATH:" in
        *":$user_bin:"*) ;;
        *) PATH="$user_bin${PATH:+:$PATH}" ;;
    esac
done
unset user_bin
# Helper commands from this repository, appended so they never shadow another command.
helpers="$HOME/.local/share/helpers/sh"
if [[ -d $helpers ]]; then
    case ":$PATH:" in
        *":$helpers:"*) ;;
        *) PATH="${PATH:+$PATH:}$helpers" ;;
    esac
fi
unset helpers
export PATH

# Opt out of telemetry in tools that honor the Console Do Not Track convention;
# tool-specific opt-outs live in ~/.bashrc.d.
export DO_NOT_TRACK=${DO_NOT_TRACK:-1}

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# Completion list colors
# ~/.inputrc colors completion lists from LS_COLORS. Readline shows words that
# are not files, such as subcommands and options, in the "missing file" color mi,
# which many distributions set to white on red, and the part already typed in
# the socket color. These entries come after the distribution's, so they win:
# such words in yellow and the typed part in bold magenta (ls also shows a broken
# symlink's target in mi). Readline reads LS_COLORS once, when it starts, and any
# `bind` starts it, so this runs before bash-completion and the snippets. To
# change a color, append an entry in ~/.bashrc.d/local.sh: LS_COLORS+=':mi=00;36'
# Nothing runs or expands here; LS_COLORS keeps its export state.
if [[ $- == *i* ]]; then
    completion_colors='mi=00;33:*.readline-colored-completion-prefix=01;35'
    case ":${LS_COLORS-}:" in
        *":$completion_colors:"*) ;;
        *) LS_COLORS="${LS_COLORS:+${LS_COLORS%:}:}$completion_colors" ;;
    esac
    unset completion_colors
fi

# Programmable completion from the bash-completion package
# https://github.com/scop/bash-completion
# Fedora loads it from /etc/bashrc; Debian and Ubuntu leave it to the user's .bashrc,
# which this file replaces, so load it here when it is missing. It loads each
# command's completion on first use (Tab), including your own files in
# ~/.local/share/bash-completion/completions, named after the command they complete.
# Skipped in POSIX mode, where bash-completion does not work.
if [[ $- == *i* && -z ${BASH_COMPLETION_VERSINFO-} ]] && ! shopt -oq posix; then
    for bash_completion in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
        if [[ -r $bash_completion ]]; then
            # shellcheck source=/dev/null
            . "$bash_completion"
            break
        fi
    done
    unset bash_completion
fi

# User specific aliases and functions
# -f skips subdirectories and dangling links (for example, after the clone moves).
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            # shellcheck source=/dev/null
            . "$rc"
        fi
    done
fi
unset rc
