# shellcheck shell=bash
# AWS CLI and SDKs
# https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-envvars.html
# Keep credentials in ~/.aws or IAM Identity Center (aws sso login), never here.

# Default region: Oregon (us-west-2), unless either variable is already set.
# AWS_REGION is read by the CLI v2 and most SDKs, AWS_DEFAULT_REGION by the CLI
# and boto3; both override a profile's region, and --region overrides both.
export AWS_REGION=${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-$AWS_REGION}

# Uncomment defaults to use them on every machine, or set them in
# ~/.bashrc.d/local.sh for this one; values already set take precedence.
# export AWS_PROFILE=${AWS_PROFILE:-default}
# export AWS_DEFAULT_OUTPUT=${AWS_DEFAULT_OUTPUT:-json}
# export AWS_PAGER=${AWS_PAGER-}  # empty disables the CLI pager

# complete -C runs its command as shell code, so the path is quoted for spaces.
if [[ $- == *i* ]] && aws_completer=$(command -v aws_completer); then
    printf -v aws_completer '%q' "$aws_completer"
    complete -C "$aws_completer" aws
fi
unset aws_completer
