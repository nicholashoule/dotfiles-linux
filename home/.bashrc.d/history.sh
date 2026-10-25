# shellcheck shell=bash
# Bash history
# https://www.gnu.org/software/bash/manual/html_node/Bash-History-Facilities.html
# Assigned directly rather than as ${VAR:-default}: bash and /etc/profile set
# HISTSIZE and HISTCONTROL before this runs, so a default would never apply.
# Override any of them in an unmanaged file that sorts later, such as local.sh.
HISTSIZE=50000                    # commands kept in memory
HISTFILESIZE=100000               # lines kept in ~/.bash_history; each timestamp takes one
HISTCONTROL=ignoreboth:erasedups  # skip commands typed with a leading space; drop duplicates
HISTIGNORE='bg:fg:clear:exit:history:ls'  # bare commands not worth recalling
HISTTIMEFORMAT='%F %T '           # record when each command ran; `history` shows it
shopt -s histappend               # append to the history file instead of overwriting it

# Save each command as soon as it runs, so closing a terminal loses nothing.
# Added once, even if this file is sourced again. Bash 5.1 and later run every
# entry of a PROMPT_COMMAND array, so history -a gets an entry of its own and
# never changes the exit status ($?) that another entry, such as the prompt,
# reads. Older Bash runs only a string, element 0, so there it goes last in that
# string, for the same reason.
if [[ ${PROMPT_COMMAND[*]-} != *'history -a'* ]]; then
    if ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))); then
        PROMPT_COMMAND+=('history -a')
    else
        PROMPT_COMMAND[0]="${PROMPT_COMMAND[0]:+${PROMPT_COMMAND[0]}; }history -a"
    fi
fi
