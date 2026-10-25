# shellcheck shell=bash
# .bash_logout
#
# Logout tasks. Bash runs this when an interactive login shell exits (console or
# SSH logins, `bash -l`), or when a non-interactive login shell runs `exit`.
# Terminal windows on the desktop start non-login shells, so closing one does not
# run it. Keep it quick and quiet: it runs as the session ends, and it must never
# fail or wait for input.
#
# Order of operations:
#   1. console     clear the screen of a Linux virtual console (tty1, tty2, ...)
#   2. local       machine-specific tasks from an unmanaged ~/.bash_logout.local

# Clear a virtual console as its outermost shell logs out, so the next person at
# the keyboard cannot read the session; clear_console (Debian, Ubuntu) also erases
# the scrollback. SSH and terminal windows are left alone: there the screen belongs
# to the user's own terminal, which stays open.
if [[ ${SHLVL-} == 1 ]] && command -v tty >/dev/null; then
    case $(tty 2>/dev/null) in
        /dev/tty[0-9]*)
            if command -v clear_console >/dev/null; then
                clear_console -q
            elif command -v clear >/dev/null; then
                clear
            fi
            ;;
    esac
fi

# Machine-specific logout tasks, such as stopping an agent this machine starts.
if [[ -f ~/.bash_logout.local ]]; then
    # shellcheck source=/dev/null
    . ~/.bash_logout.local
fi
