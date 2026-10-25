# shellcheck shell=bash
# Functions for interactive shells, grouped by purpose and sorted by name within
# each group. Aliases live in aliases.sh. Each function checks its arguments and
# the tools it needs, and reports a problem on stderr with a nonzero status:
# 2 for incorrect use, 127 for a missing tool.
[[ $- == *i* ]] || return 0

# Helpers {{{
# __dotfiles_require COMMAND...
# Succeeds when every COMMAND is installed; otherwise names the first missing one
# on behalf of the calling function and returns 127.
__dotfiles_require() {
    local command
    for command in "$@"; do
        if ! command -v "$command" >/dev/null; then
            printf '%s: %s is not installed\n' "${FUNCNAME[1]:-dotfiles}" "$command" >&2
            return 127
        fi
    done
}

# __dotfiles_usage USAGE
# Prints USAGE as a usage line and returns 2.
__dotfiles_usage() {
    printf 'usage: %s\n' "$1" >&2
    return 2
}
# }}}

# Shell {{{
# hgrep PATTERN
# Searches the shell history for PATTERN, ignoring case.
hgrep() {
    [[ $# -gt 0 ]] || { __dotfiles_usage 'hgrep PATTERN'; return; }
    __dotfiles_require grep || return
    history | grep -i -- "$*"
}

# paths
# Prints PATH one entry per line, as it is now. Pure Bash, so it works even when
# PATH itself is broken.
paths() {
    local IFS=:
    local -a entries
    read -ra entries <<<"$PATH"
    printf '%s\n' "${entries[@]}"
}

# timer
# Measures the time until Enter is pressed.
timer() {
    printf 'Timer started; press Enter to stop.\n'
    time read -r _
}
# }}}

# Network {{{
# allips
# Lists every network interface with its addresses.
allips() {
    __dotfiles_require ip || return
    ip -brief address show
}

# localip [INTERFACE]
# Prints the IPv4 address of INTERFACE, or of every interface with a global address.
localip() {
    __dotfiles_require ip || return
    if [[ $# -gt 0 ]]; then
        ip -brief -4 address show dev "$1"
    else
        ip -brief -4 address show scope global
    fi
}

# publicip [URL]
# Prints the public IP address as an HTTPS service sees it; the default is
# https://checkip.amazonaws.com. Gives up after 10 seconds.
publicip() {
    __dotfiles_require curl || return
    curl --fail --silent --show-error --max-time 10 --proto '=https' \
        "${1:-https://checkip.amazonaws.com}"
}

# sshfingerprint HOST
# Prints the fingerprints of HOST's SSH keys as ssh shows them, to compare
# before trusting a host on first connection.
sshfingerprint() {
    local keys
    [[ $# -eq 1 ]] || { __dotfiles_usage 'sshfingerprint HOST'; return; }
    __dotfiles_require ssh-keyscan ssh-keygen || return
    keys=$(ssh-keyscan -T 5 -- "$1" 2>/dev/null)
    if [[ -z $keys ]]; then
        printf 'sshfingerprint: no SSH host keys received from %s\n' "$1" >&2
        return 1
    fi
    ssh-keygen -l -f - <<<"$keys"
}
# }}}

# Text {{{
# urlencode STRING
# Prints STRING encoded for a URL query, with spaces as +, like Python's
# urllib.parse.quote_plus. Pure Bash; multibyte characters are encoded byte by byte.
urlencode() {
    local LC_ALL=C string char encoded='' i
    [[ $# -eq 1 ]] || { __dotfiles_usage 'urlencode STRING'; return; }
    string=$1
    for ((i = 0; i < ${#string}; i++)); do
        char=${string:i:1}
        case $char in
            [a-zA-Z0-9.~_-]) encoded+=$char ;;
            ' ') encoded+='+' ;;
            *)
                printf -v char '%%%02X' "'$char"
                encoded+=$char
                ;;
        esac
    done
    printf '%s\n' "$encoded"
}
# }}}

# Terminal {{{
# colors
# Prints the 16-color table: each foreground on each background.
colors() {
    local fg bg text='gYw'
    printf '\n%13s' ''
    for bg in 40m 41m 42m 43m 44m 45m 46m 47m; do
        printf '%8s' "$bg"
    done
    printf '\n'
    for fg in '    m' '   1m' '  30m' '1;30m' '  31m' '1;31m' '  32m' '1;32m' '  33m' \
        '1;33m' '  34m' '1;34m' '  35m' '1;35m' '  36m' '1;36m' '  37m' '1;37m'; do
        printf ' %s \e[%s  %s  ' "$fg" "${fg// /}" "$text"
        for bg in 40m 41m 42m 43m 44m 45m 46m 47m; do
            printf ' \e[%s\e[%s  %s  \e[0m' "${fg// /}" "$bg" "$text"
        done
        printf '\n'
    done
    printf '\n'
}

# truecolor
# Prints a 24-bit color gradient. It is smooth only when the terminal, and tmux
# if it is running, pass RGB color through; banding means they do not.
truecolor() {
    __dotfiles_require awk || return
    awk 'BEGIN {
        for (col = 0; col < 77; col++) {
            r = 255 - (col * 255 / 76); g = col * 510 / 76; b = col * 255 / 76
            if (g > 255) g = 510 - g
            printf "\033[48;2;%d;%d;%dm\033[38;2;%d;%d;%dm_\033[0m", r, g, b, 255 - r, 255 - g, 255 - b
        }
        printf "\n"
    }'
}
# }}}
