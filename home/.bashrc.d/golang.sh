# shellcheck shell=bash
# Golang
# https://pkg.go.dev/cmd/go#hdr-Environment_variables
# Uncomment defaults to use them on every machine, or set them in
# ~/.bashrc.d/local.sh for this one; values already set take precedence.
# Exports override `go env -w`. Set GOBIN or GOPATH here or with `go env -w`;
# exports from later .bashrc.d files come too late for the PATH step below.
# export GOPATH=${GOPATH:-$HOME/go}
# export GOBIN=${GOBIN:-$HOME/.local/bin}
# export GOPRIVATE=${GOPRIVATE:-github.com/example}
# export GOTOOLCHAIN=${GOTOOLCHAIN:-auto}

# One `go env` call reads GOBIN, GOPATH, and the telemetry mode. PATH gains GOBIN,
# else the first GOPATH entry's bin; output from a failed call and relative paths
# are ignored. Go telemetry (Go 1.23+) has no environment switch, so it is turned
# off with `go telemetry off`, which persists and runs only while not off.
if command -v go >/dev/null; then
    if go_env=$(go env GOBIN GOPATH GOTELEMETRY); then
        { read -r go_bin; read -r go_path; read -r go_telemetry; } <<<"$go_env"
        if [[ -z $go_bin && -n $go_path ]]; then
            go_bin="${go_path%%:*}/bin"
        fi
        if [[ $go_bin == /* ]]; then
            case ":$PATH:" in
                *":$go_bin:"*) ;;
                *) PATH="${PATH:+$PATH:}$go_bin" ;;
            esac
        fi
        if [[ -n $go_telemetry && $go_telemetry != off ]]; then
            go telemetry off
        fi
    fi
    unset go_env go_bin go_path go_telemetry
fi
