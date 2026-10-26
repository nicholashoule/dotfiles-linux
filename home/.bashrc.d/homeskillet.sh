# shellcheck shell=bash
# homeskillet
# Documentation: Shell Completion in homeskillet's docs/install.md, and `homeskillet help`.
# homeskillet writes its own completion script, so commands, options, setup step
# names, and installed versions always match the installed version. A homeskillet
# too old to have the completion command fails quietly and loads nothing.

# The generated completion runs only if homeskillet produced it successfully.
if [[ $- == *i* ]] && command -v homeskillet >/dev/null; then
    if homeskillet_completion=$(homeskillet completion bash 2>/dev/null); then
        eval "$homeskillet_completion"
    fi
    unset homeskillet_completion
fi
