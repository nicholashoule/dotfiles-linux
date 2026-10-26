# shellcheck shell=bash
# Terraform
# https://developer.hashicorp.com/terraform/cli/config/environment-variables
# OpenTofu reads these TF_* variables too. Registry tokens come from `terraform login`, never here.

# Telemetry: no checkpoint calls to HashiCorp (upgrade and security bulletin checks
# that send the version, platform, and an anonymous ID).
export CHECKPOINT_DISABLE=${CHECKPOINT_DISABLE:-1}

# Uncomment defaults to use them on every machine, or set them in
# ~/.bashrc.d/local.sh for this one; values already set take precedence.
# export TF_PLUGIN_CACHE_DIR=${TF_PLUGIN_CACHE_DIR:-$HOME/.terraform.d/plugin-cache}  # must already exist

# complete -C runs its command as shell code, so the path is quoted for spaces.
if [[ $- == *i* ]] && terraform_bin=$(command -v terraform); then
    printf -v terraform_bin '%q' "$terraform_bin"
    complete -C "$terraform_bin" terraform
fi
unset terraform_bin
