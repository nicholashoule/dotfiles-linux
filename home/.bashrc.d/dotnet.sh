# shellcheck shell=bash
# .NET SDK
# https://learn.microsoft.com/dotnet/core/tools/dotnet-environment-variables

# Telemetry: no usage data sent to Microsoft, and no first-run banner.
export DOTNET_CLI_TELEMETRY_OPTOUT=${DOTNET_CLI_TELEMETRY_OPTOUT:-1}
export DOTNET_NOLOGO=${DOTNET_NOLOGO:-1}

# A user install from the install-dotnet.sh helper lives in ~/.dotnet and goes first
# on PATH; package installs (dnf) already put dotnet on PATH.
dotnet_dir="$HOME/.dotnet"
dotnet_tools="$dotnet_dir/tools"
if [[ -x $dotnet_dir/dotnet ]]; then
    export DOTNET_ROOT=${DOTNET_ROOT:-$dotnet_dir}
    case ":$PATH:" in
        *":$dotnet_dir:"*) ;;
        *) PATH="$dotnet_dir${PATH:+:$PATH}" ;;
    esac
fi
# Global tools (dotnet tool install --global) live in ~/.dotnet/tools.
if [[ -d $dotnet_tools ]]; then
    case ":$PATH:" in
        *":$dotnet_tools:"*) ;;
        *) PATH="${PATH:+$PATH:}$dotnet_tools" ;;
    esac
fi
unset dotnet_dir dotnet_tools

# Completion as Microsoft documents it: dotnet answers through `dotnet complete`.
# https://learn.microsoft.com/dotnet/core/tools/enable-tab-autocomplete#bash
if [[ $- == *i* ]] && command -v dotnet >/dev/null; then
    _dotnet_bash_complete() {
        local cur=${COMP_WORDS[COMP_CWORD]} IFS=$'\n'
        local -a candidates
        read -d '' -ra candidates < <(dotnet complete --position "$COMP_POINT" "$COMP_LINE" 2>/dev/null)
        read -d '' -ra COMPREPLY < <(compgen -W "${candidates[*]:-}" -- "$cur")
    }
    complete -f -F _dotnet_bash_complete dotnet
fi
