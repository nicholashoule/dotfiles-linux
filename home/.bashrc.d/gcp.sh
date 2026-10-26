# shellcheck shell=bash
# Google Cloud CLI
# https://cloud.google.com/sdk/docs/properties
# CLOUDSDK_<SECTION>_<PROPERTY> overrides gcloud config; credentials stay in ~/.config/gcloud.

# Quiet by default: no survey prompts and no usage statistics sent to Google.
export CLOUDSDK_SURVEY_DISABLE_PROMPTS=${CLOUDSDK_SURVEY_DISABLE_PROMPTS:-true}
export CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=${CLOUDSDK_CORE_DISABLE_USAGE_REPORTING:-true}

# Uncomment defaults to use them on every machine, or set them in
# ~/.bashrc.d/local.sh for this one; values already set take precedence.
# export CLOUDSDK_CORE_PROJECT=${CLOUDSDK_CORE_PROJECT:-example-project}
# export CLOUDSDK_COMPUTE_REGION=${CLOUDSDK_COMPUTE_REGION:-us-central1}
# export CLOUDSDK_COMPUTE_ZONE=${CLOUDSDK_COMPUTE_ZONE:-us-central1-a}
# export GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT:-example-project}  # client libraries

# Archive install in ~/google-cloud-sdk: wired up here so install.sh need not edit .bashrc.
gcloud_sdk="$HOME/google-cloud-sdk"
if [[ -d $gcloud_sdk/bin ]]; then
    case ":$PATH:" in
        *":$gcloud_sdk/bin:"*) ;;
        *) PATH="$gcloud_sdk/bin${PATH:+:$PATH}" ;;
    esac
    if [[ $- == *i* && -f $gcloud_sdk/completion.bash.inc ]]; then
        # shellcheck source=/dev/null
        . "$gcloud_sdk/completion.bash.inc"
    fi
fi
unset gcloud_sdk
