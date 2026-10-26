# shellcheck shell=bash
# kubectl
# https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/
# Uncomment defaults to use them on every machine, or set them in
# ~/.bashrc.d/local.sh for this one; values already set take precedence.
# Kubeconfig files hold cluster credentials; keep them out of this repository.
# export KUBECONFIG=${KUBECONFIG:-$HOME/.kube/config}  # colon-separated files are merged
# export KUBE_EDITOR=${KUBE_EDITOR:-vim}

# The generated completion runs only if kubectl produced it successfully.
if [[ $- == *i* ]] && command -v kubectl >/dev/null; then
    if kubectl_completion=$(kubectl completion bash); then
        eval "$kubectl_completion"
    fi
    unset kubectl_completion
    # alias k=kubectl
    # complete -o default -F __start_kubectl k
fi
