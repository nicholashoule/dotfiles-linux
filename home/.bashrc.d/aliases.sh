# shellcheck shell=bash
# Aliases for interactive shells, grouped by purpose and sorted by name within
# each group. Functions live in functions.sh. Distributions such as Fedora
# already define ll, l., and colored ls and grep; these add to them.
[[ $- == *i* ]] || return 0

# Shell
# History and command shortcuts
alias hist='history'
alias sudo='sudo ' # the trailing space makes the next word alias-expand too

# Listing
# Long listing format with type marks and color
alias l='ls -lF --color=auto'    # long format, with type marks (/ * @)
alias la='ls -laF --color=auto'  # long format, including dotfiles
alias ll='ls -lAhF --color=auto' # long format, including hidden files, human-readable sizes
alias lsf='ls -d * --color=auto' # list only files in the current directory

# Directory listing shortcuts
alias lsd='ls -ld --color=auto'     # list only directories
alias lsda='ls -ld .* --color=auto' # list only directories and hidden files
alias lsdir='ls -d */ --color=auto' # list only directories in the current directory

# Directory navigation shortcuts
alias ..='cd ..'                          # go up one directory level
alias cd1='cd ..'                         # go up one directory level
alias ...='cd ../..'                      # go up two directory levels
alias cd2='cd ../..'                      # go up two directory levels
alias ....='cd ../../..'                  # go up three directory levels
alias cd3='cd ../../..'                   # go up three directory levels
alias .....='cd ../../../..'              # go up four directory levels
alias cd4='cd ../../../..'                # go up four directory levels
alias cd5='cd ../../../../..'             # go up five directory levels
alias cd6='cd ../../../../../..'          # go up six directory levels
alias cd7='cd ../../../../../../..'       # go up seven directory levels
alias cd8='cd ../../../../../../../..'    # go up eight directory levels
alias cd9='cd ../../../../../../../../..' # go up nine directory levels

# Tools
# Git, tmux, and other tools
alias githash='git rev-parse --short=8 HEAD' # short hash of the current commit
alias tmuxa='tmux attach -d -t'              # tmuxa SESSION: attach, detaching other clients
alias tree='tree -C'                         # color output, even when piped

# Editor shortcuts
if command -v vim >/dev/null; then
    alias vi='vim' # only when vim exists, so vi keeps working without it
fi
