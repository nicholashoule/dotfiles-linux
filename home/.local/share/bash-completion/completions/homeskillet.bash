# shellcheck shell=bash
# Bash completion for homeskillet, the manager that links these dotfiles.
# Documentation: Shell Completion in homeskillet's docs/install.md, and `homeskillet help`.
# bash-completion loads a file from this directory the first time its command is
# completed in a shell; the file is named after the command, with or without .bash.
# homeskillet writes its own completion script, so commands, options, setup names, 
# and versions always match the installed version. 

# This file only loads that script, and only when homeskillet produced it successfully.
if command -v homeskillet >/dev/null; then
    if homeskillet_completion=$(homeskillet completion bash 2>/dev/null); then
        eval "$homeskillet_completion"
    fi
    unset homeskillet_completion
fi
