# shellcheck shell=bash
# Python via uv
# https://docs.astral.sh/uv/reference/environment/
# Uncomment defaults to use them on every machine, or set them in
# ~/.bashrc.d/local.sh for this one; values already set take precedence.
# uv's standalone installer and `uv tool install` use ~/.local/bin, which .bashrc
# already adds to PATH;
# run the uv installer with UV_NO_MODIFY_PATH=1 so it leaves .bashrc alone.
# export UV_PYTHON_PREFERENCE=${UV_PYTHON_PREFERENCE:-managed}  # managed, only-managed, system, only-system
# export UV_PYTHON_DOWNLOADS=${UV_PYTHON_DOWNLOADS:-automatic}  # automatic, manual, never
# export UV_LINK_MODE=${UV_LINK_MODE:-copy}  # quiets hardlink warnings across filesystems

# Generated completions run only if uv and uvx produced them successfully.
if [[ $- == *i* ]] && command -v uv >/dev/null; then
    if uv_completion=$(uv generate-shell-completion bash); then
        eval "$uv_completion"
    fi
    if command -v uvx >/dev/null && uv_completion=$(uvx --generate-shell-completion bash); then
        eval "$uv_completion"
    fi
    unset uv_completion
fi
