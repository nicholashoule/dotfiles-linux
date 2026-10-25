# shellcheck shell=bash
# OpenTofu
# https://opentofu.org/docs/cli/config/environment-variables/
# OpenTofu also reads the TF_* variables, so defaults set in terraform.sh apply here too.
# Settings for tofu alone belong in ~/.tofurc.

# complete -C runs its command as shell code, so the path is quoted for spaces.
if [[ $- == *i* ]] && tofu_bin=$(command -v tofu); then
    printf -v tofu_bin '%q' "$tofu_bin"
    complete -C "$tofu_bin" tofu
fi
unset tofu_bin
