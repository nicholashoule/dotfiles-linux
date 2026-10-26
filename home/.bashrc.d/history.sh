# shellcheck shell=bash
# Bash history
# https://www.gnu.org/software/bash/manual/html_node/Bash-History-Facilities.html
# Two layers keep every command without slowing the shell. Bash reads the whole
# history file into every new shell and keeps the list in memory, so the live
# history (HISTSIZE, HISTFILESIZE) is sized to load fast: a million commands
# would add about 0.3 s to each new shell and 140 MB to each open one, 100,000
# about 0.03 s and 17 MB. Every command also goes to an archive that bash never
# loads, so nothing is lost; hgrep searches it.

# The archive: ~/.local/state/bash/history unless HISTARCHIVE is set, in a
# ~/.bashrc.d file that sorts before this one (such as 00-local.sh) or in the
# environment. The first shell to find it missing starts it from ~/.bash_history,
# before HISTFILESIZE below trims that file; noclobber leaves it alone for a
# second shell starting at the same moment. Like ~/.bash_history, only you can
# read it.
HISTARCHIVE=${HISTARCHIVE:-${XDG_STATE_HOME:-$HOME/.local/state}/bash/history}
if [[ $- == *i* && ! -e $HISTARCHIVE ]]; then
    (
        umask 077
        mkdir -p -- "${HISTARCHIVE%/*}" && set -C && cat -- "${HISTFILE:-$HOME/.bash_history}" >"$HISTARCHIVE"
    ) 2>/dev/null
fi

# Assigned directly rather than as ${VAR:-default}: bash and /etc/profile set
# HISTSIZE and HISTCONTROL before this runs, so a default would never apply.
# Override any of them in an unmanaged file that sorts later, such as local.sh.
HISTSIZE=100000                          # commands kept in memory
HISTFILESIZE=200000                      # lines kept in ~/.bash_history: HISTSIZE commands and their timestamps
HISTCONTROL=ignoreboth:erasedups         # skip commands typed with a leading space; drop duplicates
HISTIGNORE='bg:fg:clear:exit:history:ls' # bare commands not worth recalling
HISTTIMEFORMAT='%F %T '                  # record when each command ran; `history` shows it
shopt -s histappend                      # append to the history file instead of overwriting it

# __dotfiles_history_save saves the newest command as soon as it runs, so closing
# a terminal loses nothing: history -a appends it to ~/.bash_history, and it is
# appended to the archive with its time, once. The first call in a shell only
# notes the newest entry, which came from the history file; after that, a
# changed entry is a new command. Commands that history skips (a leading space,
# HISTIGNORE, a repeat) and empty lines change nothing. A single append per
# command never overwrites another shell's, and $? is kept for the prompt. An
# archive deleted meanwhile is created again, readable only by you.
__dotfiles_history_save() {
    local status=$? entry HISTTIMEFORMAT=
    builtin history -a
    entry=$(builtin history 1)
    if [[ -n ${__dotfiles_history_last+set} && $entry != "$__dotfiles_history_last" ]] &&
        [[ $entry =~ ^[[:space:]]*[0-9]+\*?[[:space:]][[:space:]](.+)$ ]]; then
        if [[ ! -e $HISTARCHIVE ]]; then
            (umask 077 && mkdir -p -- "${HISTARCHIVE%/*}" && : >>"$HISTARCHIVE") 2>/dev/null
        fi
        printf '#%(%s)T\n%s\n' -1 "${BASH_REMATCH[1]}" 2>/dev/null >>"$HISTARCHIVE"
    fi
    __dotfiles_history_last=$entry
    return "$status"
}

# Added once, even if this file is sourced again. Bash 5.1 and later run every
# entry of a PROMPT_COMMAND array, so the save gets an entry of its own and
# never changes the exit status ($?) that another entry, such as the prompt,
# reads. Older Bash runs only a string, element 0, so there it goes last in that
# string, for the same reason.
if [[ ${PROMPT_COMMAND[*]-} != *__dotfiles_history_save* ]]; then
    if ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))); then
        PROMPT_COMMAND+=('__dotfiles_history_save')
    else
        PROMPT_COMMAND[0]="${PROMPT_COMMAND[0]:+${PROMPT_COMMAND[0]}; }__dotfiles_history_save"
    fi
fi
