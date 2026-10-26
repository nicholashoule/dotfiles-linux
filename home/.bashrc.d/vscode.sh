# shellcheck shell=bash
# Visual Studio Code
# https://code.visualstudio.com/docs/setup/linux
# Package installs put `code` on PATH. VS Code telemetry is a setting, not an
# environment variable: set "telemetry.telemetryLevel": "off" in settings.json.
# There, "extensions.showRecommendationsOnlyOnDemand": true hides the Extensions
# view's Recommended section, and "extensions.ignoreRecommendations": true stops
# recommendation pop-ups. VS Code writes settings.json, so it is never linked.

# code_extensions_install installs the extensions listed below that are missing.
# Edit the list to match yours; `code --list-extensions` prints what is installed.
code_extensions_install() {
    local extension installed
    local -a missing=()
    if ! command -v code >/dev/null; then
        printf 'code_extensions_install: code is not installed\n' >&2
        return 1
    fi
    installed=$(code --list-extensions) || return
    while IFS= read -r extension; do
        if [[ -n $extension ]] && ! grep -qixF -- "$extension" <<<"$installed"; then
            missing+=(--install-extension "$extension")
        fi
    done <<'EOF'
anthropic.claude-code
esbenp.prettier-vscode
github.github-vscode-theme
golang.go
ms-azuretools.vscode-containers
ms-azuretools.vscode-docker
ms-dotnettools.csharp
ms-dotnettools.vscode-dotnet-runtime
ms-python.debugpy
ms-python.python
ms-python.vscode-pylance
ms-python.vscode-python-envs
ms-vscode.cmake-tools
ms-vscode.cpp-devtools
ms-vscode.cpptools
ms-vscode.cpptools-extension-pack
ms-vscode.cpptools-themes
ms-vscode.makefile-tools
ms-vscode.powershell
vscode-icons-team.vscode-icons
EOF
    if [[ ${#missing[@]} -eq 0 ]]; then
        printf 'All listed extensions are installed.\n'
        return 0
    fi
    code "${missing[@]}"
}

# code_settings_apply [SETTINGS_FILE] adds the settings below to VS Code's user
# settings.json (or SETTINGS_FILE) when missing; one already there, even
# commented out, keeps your value. The file must exist and start with a line
# holding only {, as VS Code writes it; the settings go after that line, and the
# old file is kept as SETTINGS_FILE.bak.DATE-TIME.
code_settings_apply() {
    local file line insert tmp tool
    local -a missing=()
    [[ $# -le 1 ]] || { printf 'usage: code_settings_apply [SETTINGS_FILE]\n' >&2; return 2; }
    for tool in cp date grep head mktemp tail; do
        command -v "$tool" >/dev/null || { printf 'code_settings_apply: %s is not installed\n' "$tool" >&2; return 127; }
    done
    file=${1:-${XDG_CONFIG_HOME:-$HOME/.config}/Code/User/settings.json}
    if [[ ! -f $file || ! $(head -n 1 "$file") =~ ^\{[[:space:]]*$ ]]; then
        printf 'code_settings_apply: %s is missing or does not start with a { line; open VS Code settings first\n' "$file" >&2
        return 1
    fi
    while IFS= read -r line; do
        grep -qF -- "${line%%:*}" "$file" || missing+=("$line")
    done <<'SETTINGS'
"telemetry.telemetryLevel": "off"
"extensions.ignoreRecommendations": true
"extensions.showRecommendationsOnlyOnDemand": true
SETTINGS
    [[ ${#missing[@]} -gt 0 ]] || { printf '%s already has these settings.\n' "$file"; return 0; }
    insert=$(printf '    %s,\n' "${missing[@]}")
    # An empty object, { then }, takes no comma after its last setting.
    [[ ! $(head -n 2 "$file" | tail -n 1) =~ ^[[:space:]]*\} ]] || insert=${insert%,}
    tmp=$(mktemp) || return
    { head -n 1 "$file"; printf '%s\n' "$insert"; tail -n +2 "$file"; } >"$tmp"
    if ! cp -p -- "$file" "$file.bak.$(date +%Y%m%d-%H%M%S)" || ! cat -- "$tmp" >"$file"; then
        rm -f -- "$tmp"
        printf 'code_settings_apply: could not update %s\n' "$file" >&2
        return 1
    fi
    rm -f -- "$tmp"
    printf 'Added to %s:\n' "$file"
    printf '    %s\n' "${missing[@]}"
}
