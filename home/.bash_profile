# shellcheck shell=bash
# .bash_profile
#
# Login shell setup. Bash reads this for login shells (console or SSH logins,
# `bash -l`). It reads only the first of ~/.bash_profile, ~/.bash_login, and
# ~/.profile, so ~/.profile is ignored while this file exists.
#
# Order of operations:
#   1. /etc/profile    system login environment, read by bash before this file
#   2. ~/.bashrc       shared setup, so login and non-login shells match
#   3. login tasks     below; they run for login shells only, not every new shell
#
# Keep per-shell settings (aliases, completions, prompt) in ~/.bashrc or
# ~/.bashrc.d; this file is for work that only needs to happen at login.

# Shared setup from ~/.bashrc, first so the login tasks below see its PATH
if [ -f ~/.bashrc ]; then
    # shellcheck source=/dev/null
    . ~/.bashrc
fi

# User specific environment and startup programs

# Terminal settings for Ptyxis and GNOME Terminal (VS Code uses its own settings.json)
# Needs gsettings and a user D-Bus session; GNOME starts its session through a login
# shell, so these apply at each graphical login. A terminal's keys are all read before
# any is written, so logins where they already match make no changes; missing terminal
# schemas are skipped, and the GNOME Terminal profile ID must look like a UUID before
# it is used in a dconf path. Values are GVariant text, as `gsettings get` prints them.
# Changes made in a terminal's preferences are restored at the next login.
#
# Font: a Nerd Font for Oh My Posh glyphs (installed via: oh-my-posh font install meslo)
# https://ohmyposh.dev/docs/configuration/concepts
#
# Copy and paste: Ctrl+C and Ctrl+V, replacing Ctrl+Shift+C and Ctrl+Shift+V.
# Ptyxis turns copy off while nothing is selected, so Ctrl+C then reaches the program
# as an interrupt. GNOME Terminal consumes its copy shortcut even with nothing
# selected, which would leave no interrupt key, so it keeps Ctrl+Shift+C for copy.
# Ctrl+V pastes while the clipboard holds text; Vim also starts block selection on Ctrl+Q.
if command -v gsettings >/dev/null && [[ -n $DBUS_SESSION_BUS_ADDRESS || -S ${XDG_RUNTIME_DIR:-/run/user/$UID}/bus ]]; then
    TERMINAL_FONT='MesloLGL Nerd Font 10'
    _set_terminal() { # $1 = schema[:path], then key and value pairs
        local schema i
        local -a pairs current
        schema=$1
        shift
        pairs=("$@")
        for ((i = 0; i < ${#pairs[@]}; i += 2)); do
            current[i]=$(gsettings get "$schema" "${pairs[i]}" 2>/dev/null) || return 0
        done
        for ((i = 0; i < ${#pairs[@]}; i += 2)); do
            [[ ${current[i]} == "${pairs[i + 1]}" ]] && continue
            gsettings set "$schema" "${pairs[i]}" "${pairs[i + 1]}" || return
        done
    }
    _set_terminal org.gnome.Ptyxis use-system-font false font-name "'$TERMINAL_FONT'"
    _set_terminal org.gnome.Ptyxis.Shortcuts copy-clipboard "'<ctrl>c'" paste-clipboard "'<ctrl>v'"
    _set_terminal org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/keybindings/ paste "'<Control>v'"
    if terminal_profile=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null); then
        terminal_profile=${terminal_profile#\'}
        terminal_profile=${terminal_profile%\'}
        if [[ $terminal_profile =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
            _set_terminal "org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$terminal_profile/" \
                use-system-font false font "'$TERMINAL_FONT'"
        fi
    fi
    unset terminal_profile
    unset -f _set_terminal
fi
