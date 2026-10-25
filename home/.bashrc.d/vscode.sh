# shellcheck shell=bash
# Visual Studio Code
# https://code.visualstudio.com/docs/setup/linux
# Package installs put `code` on PATH. VS Code telemetry is a setting, not an
# environment variable: set "telemetry.telemetryLevel": "off" in settings.json.

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
