#!/usr/bin/env bash
# Regression checks for the shell startup files and, optionally, the manager.
#
# Usage: bash tests/check.sh [MANAGER]
#
# Each shell check runs a startup file with bash in an empty environment (env -i)
# and a throwaway HOME, so nothing reads or changes your real home. Passing a built
# homeskillet binary as MANAGER also links, checks, and unlinks every file under
# home/ in a temporary home, and dry-runs the setup steps.
# Exit status: 0 when all checks pass, 1 when a check fails, 2 for usage errors.

# POSIX syntax until bash is confirmed, so `sh tests/check.sh` fails clearly.
if [ -z "${BASH_VERSION:-}" ]; then
    printf 'check.sh: run with bash: bash tests/check.sh\n' >&2
    exit 2
fi
set -euo pipefail
# CDPATH can redirect cd to another directory and make it print the path.
unset CDPATH

# Global variables
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly REPO
MANAGER=''
MANAGER_OUTPUT=''
SED_BIN=''
SNIPPETS=()
TEST_ROOT=''

# usage information
usage() {
    printf 'Usage: bash tests/check.sh [MANAGER]\n'
    printf 'Runs the shell regression checks; with a homeskillet binary as MANAGER,\n'
    printf 'also links, checks, and unlinks every file under home/ in a temporary home.\n'
}

# die prints an error message and exits with status 2.
die() {
    printf 'check.sh: %s\n' "$1" >&2
    exit 2
}

# pass prints a success message for the given test name.
pass() {
    printf 'ok   %s\n' "$1"
}

# skip reports a check that cannot run here, such as one needing an absent tool.
skip() {
    printf 'skip %s: %s\n' "$1" "$2"
}

# fail prints a failure message for the given test name and reason, then exits.
fail() {
    printf 'FAIL %s: %s\n' "$1" "$2" >&2
    exit 1
}

# cleanup removes the temporary test root directory if it exists.
cleanup() {
    if [[ -n $TEST_ROOT && -d $TEST_ROOT ]]; then
        rm -rf -- "$TEST_ROOT"
    fi
}

# setup prepares the environment for the tests, checking required commands,
# locating snippets, and creating a temporary test root.
setup() {
    local cmd
    for cmd in env find ls mktemp readlink sed; do
        command -v "$cmd" >/dev/null || die "missing required command: $cmd"
    done
    SED_BIN=$(command -v sed)
    # Git in the throwaway repositories ignores the user's and the system's config,
    # so commit signing, hooks, and templates set there never run or prompt here.
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

    SNIPPETS=("$REPO"/home/.bashrc.d/*)
    [[ -f ${SNIPPETS[0]} ]] || die "no snippets found in $REPO/home/.bashrc.d"

    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-check.XXXXXX")
}

# new_home prints a new empty directory to use as HOME.
new_home() {
    mktemp -d "$TEST_ROOT/home.XXXXXX"
}

# expect NAME EXPECTED HOME [VAR=value...] -- [ARG...] < script
# Runs the script on stdin with bash in an empty environment holding only HOME,
# PATH=/nonexistent, and any VAR=value given. It must exit zero and print exactly
# EXPECTED, stderr included, so stray warnings fail the check too.
expect() {
    local name=$1 expected=$2 home=$3 output status=0
    local -a vars=()
    shift 3
    while [[ $# -gt 0 && $1 != -- ]]; do
        vars+=("$1")
        shift
    done
    [[ ${1-} == -- ]] || die "expect: missing -- for '$name'"
    shift
    output=$(env -i HOME="$home" PATH=/nonexistent ${vars[@]+"${vars[@]}"} \
        "$BASH" --noprofile --norc -s -- "$@" 2>&1) || status=$?
    if [[ $status -ne 0 ]]; then
        fail "$name" "exit status $status: $output"
    elif [[ $output != "$expected" ]]; then
        fail "$name" "expected '$expected', got '$output'"
    fi
    pass "$name"
}

# manage HOME COMMAND [OPTION...]
# Runs a manager command for this repository against HOME and keeps its output in
# MANAGER_OUTPUT; a nonzero exit fails with that output.
manage() {
    local home=$1 command=$2 status=0
    shift 2
    MANAGER_OUTPUT=$("$MANAGER" "$command" --repo "$REPO" --home "$home" "$@" 2>&1) || status=$?
    if [[ $status -ne 0 ]]; then
        fail "homeskillet $command${*:+ $*}" "exit status $status: $MANAGER_OUTPUT"
    fi
}

# .bashrc prepends the user bins once, and its ~/.bashrc.d loop runs golang.sh,
# which appends the Go bin directory for each `go env` outcome. The go stubs print
# GOBIN, GOPATH, and GOTELEMETRY on separate lines, as `go env` does.
check_shell_path() {
    local home mode label prefix suffix
    home=$(new_home)
    mkdir "$home/.bashrc.d"
    ln -s "$REPO/home/.bashrc.d/golang.sh" "$home/.bashrc.d/golang.sh"
    for mode in absent failure partial gopath gobin relative telemetry; do
        prefix=''
        suffix=''
        case $mode in
            absent) label='go not installed' ;;
            failure) label='go env fails' ;;
            partial) label='go env fails after output' ;;
            gopath) label='GOPATH from go env' suffix=:/tools/go/bin ;;
            gobin) label='GOBIN from go env' suffix=:/tools/bin ;;
            relative) label='relative GOBIN skipped' ;;
            telemetry)
                label='Go telemetry switched off'
                prefix='[go telemetry off][go telemetry off]'
                suffix=:/tools/bin
                ;;
        esac
        expect ".bashrc PATH, $label" "$prefix$home/.local/bin:$home/bin:/nonexistent$suffix" \
            "$home" -- "$mode" "$REPO/home/.bashrc" "$SED_BIN" <<'BASH'
case $1 in
    failure) go() { return 1; } ;;
    partial) go() { printf '/tools/bin'; return 1; } ;;
    gopath) go() { printf '\n/tools/go:/other/go\noff\n'; } ;;
    gobin) go() { printf '/tools/bin\n/tools/go\noff\n'; } ;;
    relative) go() { printf 'relative/bin\n\noff\n'; } ;;
    telemetry)
        go() {
            if [[ $1 == env ]]; then printf '/tools/bin\n\nlocal\n'; else printf '[go %s]' "$*"; fi
        }
        ;;
esac
for attempt in 1 2; do
    source <("$3" -n '/^# User specific environment$/,$p' "$2")
done
printf '%s' "$PATH"
BASH
    done
}

# .bash_profile skips terminals whose gsettings schemas are missing, without writes.
# With Ptyxis and GNOME Terminal at their defaults, the first login sets the font and
# the copy and paste shortcuts (GNOME Terminal keeps its copy key), and a second login
# writes nothing. The gsettings stub prints each write as "schema key=value".
check_terminal_settings() {
    local home profile keys expected
    home=$(new_home)
    expect ".bash_profile terminals, schemas missing" '' "$home" \
        DBUS_SESSION_BUS_ADDRESS=test-session -- "$REPO/home/.bash_profile" <<'BASH'
gsettings() {
    if [[ $1 == set ]]; then printf 'unexpected write'; fi
    return 1
}
source "$1"
BASH

    profile=org.gnome.Terminal.Legacy.Profile
    keys=org.gnome.Terminal.Legacy.Keybindings
    expected="org.gnome.Ptyxis use-system-font=false
org.gnome.Ptyxis font-name='MesloLGL Nerd Font 10'
org.gnome.Ptyxis.Shortcuts copy-clipboard='<ctrl>c'
org.gnome.Ptyxis.Shortcuts paste-clipboard='<ctrl>v'
$keys paste='<Control>v'
$profile use-system-font=false
$profile font='MesloLGL Nerd Font 10'
second login"
    expect ".bash_profile terminals, defaults" "$expected" "$home" \
        DBUS_SESSION_BUS_ADDRESS=test-session -- "$REPO/home/.bash_profile" <<'BASH'
uuid=b1dcc9dd-5262-4d8d-a863-c897e6d979b9
profile="org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:$uuid/"
keys=org.gnome.Terminal.Legacy.Keybindings:/org/gnome/terminal/legacy/keybindings/
declare -A settings=(
    ['org.gnome.Ptyxis use-system-font']=true
    ['org.gnome.Ptyxis font-name']="'Monospace 11'"
    ['org.gnome.Ptyxis.Shortcuts copy-clipboard']="'<ctrl><shift>c'"
    ['org.gnome.Ptyxis.Shortcuts paste-clipboard']="'<ctrl><shift>v'"
    ['org.gnome.Terminal.ProfilesList default']="'$uuid'"
    ["$profile use-system-font"]=true
    ["$profile font"]="'Monospace 12'"
    ["$keys copy"]="'<Control><Shift>c'"
    ["$keys paste"]="'<Control><Shift>v'"
)
gsettings() {
    [[ ${settings["$2 $3"]+set} ]] || return 1
    case $1 in
        get) printf '%s\n' "${settings["$2 $3"]}" ;;
        set) settings["$2 $3"]=$4 && printf '%s %s=%s\n' "${2%%:*}" "$3" "$4" ;;
        *) return 1 ;;
    esac
}
source "$1"
printf 'second login'
source "$1"
BASH
}

# stub_manager DIR MODE writes a stand-in homeskillet into DIR for the homeskillet.sh
# checks. Its completion command succeeds with a script that registers a
# completion (ok), or prints code that must never run and fails (fail), or is
# missing with an error, as in a homeskillet too old to have it (old).
stub_manager() {
    local dir=$1 mode=$2
    mkdir -p "$dir"
    case $mode in
        ok)
            cat >"$dir/homeskillet" <<'SH'
#!/bin/sh
[ "$1 $2" = 'completion bash' ] || exit 2
printf '%s\n' '_homeskillet() { :; }' 'complete -o filenames -F _homeskillet homeskillet'
SH
            ;;
        fail)
            cat >"$dir/homeskillet" <<'SH'
#!/bin/sh
printf '%s\n' 'printf evaluated'
exit 1
SH
            ;;
        old)
            cat >"$dir/homeskillet" <<'SH'
#!/bin/sh
echo 'homeskillet: unknown command "completion"' >&2
exit 1
SH
            ;;
    esac
    chmod +x "$dir/homeskillet"
}

# Every file in home/.local/share/bash-completion/completions, sourced alone, registers
# a completion for the command it is named after (less .bash) and prints nothing,
# and passes ShellCheck when it is installed. The directory holds no files until a
# shared completion is added, so the ShellCheck commands leave it to this check.
check_completion_files() {
    local home file name output
    home=$(new_home)
    for file in "$REPO"/home/.local/share/bash-completion/completions/*; do
        [[ -f $file ]] || continue
        name=${file##*/}
        name=${name%.bash}
        expect "completion file for $name" registered "$home" -- "$file" "$name" <<'BASH'
source "$1"
complete -p -- "$2" >/dev/null && printf registered
BASH
        if ! command -v shellcheck >/dev/null; then
            skip "completion file for $name, ShellCheck" "shellcheck is not installed"
            continue
        fi
        output=$(shellcheck -- "$file" 2>&1) || fail "completion file for $name, ShellCheck" "$output"
        pass "completion file for $name passes ShellCheck"
    done
}

# homeskillet.sh loads the script homeskillet writes itself (homeskillet completion
# bash) only when that command succeeds: a failing command's output never runs, and
# a homeskillet too old to have the command, or none at all, leaves nothing
# registered and prints nothing. Its helper variable is unset. Its interactive-only
# guard is removed, because the sandbox shell is not interactive; with the guard,
# a non-interactive shell loads nothing.
check_homeskillet_completion() {
    local home mode expected
    for mode in ok fail old none; do
        home=$(new_home)
        expected=''
        if [[ $mode == ok ]]; then
            expected='complete -o filenames -F _homeskillet homeskillet'
        fi
        if [[ $mode != none ]]; then
            stub_manager "$home/bin" "$mode"
        fi
        expect "homeskillet.sh completion, generator $mode" "$expected" "$home" PATH="$home/bin" -- \
            "$REPO/home/.bashrc.d/homeskillet.sh" "$SED_BIN" <<'BASH'
source <("$2" 's/\[\[ \$- == \*i\* \]\] && //' "$1")
complete -p homeskillet 2>/dev/null
if [[ -v homeskillet_completion ]]; then printf ' helper variable left set'; fi
BASH
    done
    home=$(new_home)
    stub_manager "$home/bin" ok
    expect "homeskillet.sh completion, non-interactive" '' "$home" PATH="$home/bin" -- \
        "$REPO/home/.bashrc.d/homeskillet.sh" <<'BASH'
source "$1"
complete -p homeskillet 2>/dev/null || :
BASH
}

# With bash-completion installed, an interactive .bashrc loads it, and it loads a
# completion from the user directory on first use: here a throwaway mytool.bash.
# An empty compatibility directory keeps out the system's extra completion files,
# so the default handler is bash-completion's own.
check_completion_loading() {
    local home dir
    if [[ ! -r /usr/share/bash-completion/bash_completion && ! -r /etc/bash_completion ]]; then
        skip "bash-completion loading" "bash-completion is not installed"
        return
    fi
    home=$(new_home)
    dir="$home/.local/share/bash-completion/completions"
    mkdir -p "$dir" "$home/compat"
    printf '%s\n' '_mytool() { :; }' 'complete -o filenames -F _mytool mytool' >"$dir/mytool.bash"
    expect "bash-completion loads a user completion on first use" \
        'loaded|124|complete -o filenames -F _mytool mytool' "$home" \
        PATH="/usr/bin:/bin" BASH_COMPLETION_COMPAT_DIR="$home/compat" -- "$REPO/home/.bashrc" "$SED_BIN" <<'BASH'
source <("$2" -n -e 's/\$- == \*i\* && //' -e '/^# User specific environment$/,$p' "$1")
if [[ -n ${BASH_COMPLETION_VERSINFO-} ]]; then printf 'loaded|'; fi
complete -p mytool 2>/dev/null
loader=$(complete -p -D)
loader=${loader#*-F }
"${loader%% *}" mytool '' mytool
printf '%s|' "$?"
complete -p mytool
BASH
}

# Every ~/.bashrc.d snippet is silent and leaves PATH alone when its tool is missing.
check_snippets_without_tools() {
    local home rc
    home=$(new_home)
    for rc in "${SNIPPETS[@]}"; do
        expect "${rc##*/}, tool missing" /nonexistent "$home" -- "$rc" <<'BASH'
source "$1"
printf '%s' "$PATH"
BASH
    done
}

# aws.sh defaults both region variables to Oregon; either preset value wins.
check_aws_region() {
    local home preset expected
    home=$(new_home)
    for preset in '' AWS_REGION=eu-west-1 AWS_DEFAULT_REGION=eu-west-1; do
        expected='us-west-2 us-west-2'
        if [[ -n $preset ]]; then
            expected='eu-west-1 eu-west-1'
        fi
        expect "aws.sh region, ${preset:-nothing preset}" "$expected" "$home" \
            ${preset:+"$preset"} -- "$REPO/home/.bashrc.d/aws.sh" <<'BASH'
source "$1"
printf '%s %s' "$AWS_REGION" "$AWS_DEFAULT_REGION"
BASH
    done
}

# Telemetry opt-outs from .bashrc, gcp.sh, terraform.sh, and dotnet.sh are on by
# default, and values already in the environment win.
check_telemetry_defaults() {
    local home scenario expected
    local -a vars
    home=$(new_home)
    for scenario in defaults presets; do
        vars=()
        expected='1 true true 1 1'
        if [[ $scenario == presets ]]; then
            vars=(DO_NOT_TRACK=0 CLOUDSDK_SURVEY_DISABLE_PROMPTS=false
                CLOUDSDK_CORE_DISABLE_USAGE_REPORTING=false CHECKPOINT_DISABLE=0
                DOTNET_CLI_TELEMETRY_OPTOUT=0)
            expected='0 false false 0 0'
        fi
        expect "telemetry opt-outs, $scenario" "$expected" "$home" ${vars[@]+"${vars[@]}"} \
            -- "$REPO/home" "$SED_BIN" <<'BASH'
source <("$2" -n '/^# User specific environment$/,$p' "$1/.bashrc")
for rc in gcp terraform dotnet; do
    source "$1/.bashrc.d/$rc.sh"
done
printf '%s %s %s %s %s' "$DO_NOT_TRACK" "$CLOUDSDK_SURVEY_DISABLE_PROMPTS" \
    "$CLOUDSDK_CORE_DISABLE_USAGE_REPORTING" "$CHECKPOINT_DISABLE" "$DOTNET_CLI_TELEMETRY_OPTOUT"
BASH
    done
}

# functions.sh helpers work without external tools where they can, and report
# incorrect use (status 2) or a missing tool (status 127) clearly. Its
# interactive-only guard is removed, because the sandbox shell is not interactive.
check_functions() {
    local home
    home=$(new_home)
    expect "functions.sh helpers" \
        'a+b%26c%2F%C3%A9~_.-%2B%25|/a|/b c|usage: hgrep PATTERN (2)|publicip: curl is not installed (127)' \
        "$home" -- "$REPO/home/.bashrc.d/functions.sh" "$SED_BIN" <<'BASH'
source <("$2" '/^\[\[ \$- == \*i\* \]\] || return 0$/d' "$1")
printf '%s|' "$(urlencode 'a b&c/é~_.-+%')"
PATH='/a:/b c' paths | { read -r first; read -r second; printf '%s|%s|' "$first" "$second"; }
message=$(hgrep 2>&1)
printf '%s (%s)|' "$message" "$?"
message=$(publicip 2>&1)
printf '%s (%s)' "$message" "$?"
BASH
}

# run_secret_scan HOME REPO MODE prints the output of scripts/check-secrets.sh run
# in REPO with HOME, ignoring the real global Git config, and returns its status.
run_secret_scan() {
    (cd "$2" && env -i HOME="$1" PATH="$PATH" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
        "$BASH" "$REPO/scripts/check-secrets.sh" "$3" 2>&1)
}

# scripts/check-secrets.sh passes clean content; blocks secrets without printing
# them, force-added ignored files, and personal details; honors the allow marker
# and !exceptions; and checks committed files with --all. The fake secrets are
# assembled at run time, so this file never contains one.
check_secret_scan() {
    local home repo output status aws aws_secret github key expected
    if ! command -v git >/dev/null; then
        skip "secret scan" "git is not installed"
        return
    fi
    home=$(new_home)
    repo="$home/repo"
    aws="AKIA""$(printf 'Q%.0s' {1..16})"
    aws_secret="$(printf 'k%.0s' {1..40})"
    github="ghp_""$(printf 'a%.0s' {1..36})"
    key="-----BEGIN OPENSSH ""PRIVATE KEY-----"
    git init -q "$repo"
    cp "$REPO/.gitignore" "$repo/.gitignore"
    git -C "$repo" config user.email 'tester@example.invalid'
    git -C "$repo" config user.name 'Tester'

    printf 'hello\n' >"$repo/notes.txt"
    git -C "$repo" add .gitignore notes.txt
    status=0
    output=$(run_secret_scan "$home" "$repo" --staged) || status=$?
    [[ $status -eq 0 && -z $output ]] || fail "secret scan, clean" "exit status $status: $output"
    pass "secret scan, clean content passes"

    printf 'id=%s\ntoken=%s\n%s\nallowed=%s # secret-scan: allow\nexport AWS_SECRET_ACCESS_KEY=%s\n' \
        "$aws" "$github" "$key" "$github" "$aws_secret" >"$repo/config.txt"
    mkdir -p "$repo/home/.aws"
    printf '[default]\n' >"$repo/home/.aws/credentials"
    printf 'path=%s/x\nemail=tester@example.invalid\n' "$home" >"$repo/personal.txt"
    git -C "$repo" add config.txt personal.txt
    git -C "$repo" add -f home/.aws/credentials
    status=0
    output=$(run_secret_scan "$home" "$repo" --staged) || status=$?
    [[ $status -eq 1 ]] || fail "secret scan, findings" "exit status $status: $output"
    for expected in 'config.txt:1: AWS access key ID' 'config.txt:2: GitHub token' \
        'config.txt:3: private key' 'config.txt:5: AWS secret access key' \
        'home/.aws/credentials: ignored by .gitignore' 'personal.txt:1: home directory path' \
        'personal.txt:2: Git user email' '7 finding(s)'; do
        [[ $output == *"$expected"* ]] || fail "secret scan, findings" "missing '$expected' in: $output"
    done
    [[ $output != *"$aws"* && $output != *"$github"* && $output != *"$aws_secret"* ]] ||
        fail "secret scan, findings" "the output prints a secret"
    pass "secret scan blocks secrets, ignored files, and personal details unprinted"

    git -C "$repo" commit -q -m test
    status=0
    output=$(run_secret_scan "$home" "$repo" --all) || status=$?
    [[ $status -eq 1 && $output == *'config.txt:1: AWS access key ID'* ]] ||
        fail "secret scan, --all" "exit status $status: $output"
    pass "secret scan --all checks committed files"

    printf 'save-exact=true\n' >"$repo/home/.npmrc"
    git -C "$repo" add -f home/.npmrc
    output=$(run_secret_scan "$home" "$repo" --staged) || true
    [[ $output == *'home/.npmrc: ignored by'* ]] || fail "secret scan, exception" "not blocked: $output"
    printf '!home/.npmrc\n' >>"$repo/.gitignore"
    git -C "$repo" add .gitignore
    status=0
    output=$(run_secret_scan "$home" "$repo" --staged) || status=$?
    [[ $status -eq 0 ]] || fail "secret scan, exception" "exit status $status: $output"
    pass "secret scan accepts a file with a !exception in .gitignore"
}

# run_hook HOME REPO [VAR=value...] prints the output of .githooks/pre-commit run
# in REPO with HOME, HOME/bin first on PATH, and the variables, ignoring the real
# global Git config, and returns its status.
run_hook() {
    (cd "$2" && env -i HOME="$1" PATH="$1/bin:$PATH" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
        "${@:3}" "$BASH" .githooks/pre-commit 2>&1)
}

# .githooks/pre-commit checks the staged content, not the working tree: it passes
# clean files, blocks a secret and a syntax error (also in a file found only by
# its shebang), and blocks shellcheck warnings when shellcheck is installed. It
# runs pre-commit, a stub here, with that file's ShellCheck hook added to SKIP,
# blocks the commit when pre-commit fails, and skips it when it is not installed.
check_pre_commit_hook() {
    local home repo output status token
    if ! command -v git >/dev/null; then
        skip "pre-commit hook" "git is not installed"
        return
    fi
    home=$(new_home)
    repo="$home/repo"
    token="ghp_""$(printf 'c%.0s' {1..36})"
    git init -q "$repo"
    mkdir -p "$repo/.githooks" "$repo/scripts" "$repo/tools"
    cp "$REPO/.githooks/pre-commit" "$repo/.githooks/pre-commit"
    cp "$REPO/scripts/check-secrets.sh" "$repo/scripts/check-secrets.sh"
    cp "$REPO/.gitignore" "$repo/.gitignore"
    # The stub pre-commit records how it was run, and fails when STUB_STATUS says.
    mkdir -p "$home/bin"
    cat >"$home/bin/pre-commit" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s SKIP=%s\n' "$*" "${SKIP-}" >"$HOME/pre-commit.log"
exit "${STUB_STATUS:-0}"
SCRIPT
    chmod +x "$home/bin/pre-commit"

    cat >"$repo/tools/run" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' "$1"
SCRIPT
    cp "$repo/tools/run" "$repo/tool.sh"
    git -C "$repo" add tools/run tool.sh
    printf 'if then\n' >>"$repo/tool.sh"
    status=0
    output=$(run_hook "$home" "$repo") || status=$?
    [[ $status -eq 0 ]] || fail "pre-commit, clean staged content" "exit status $status: $output"
    pass "pre-commit passes clean staged content, whatever the working tree holds"

    printf 'if then\n' >>"$repo/tools/run"
    printf 'token=%s\n' "$token" >"$repo/leak.txt"
    git -C "$repo" add tools/run leak.txt
    status=0
    output=$(run_hook "$home" "$repo") || status=$?
    [[ $status -eq 1 && $output == *'tools/run'* && $output == *'failed: secret scan, bash -n'* ]] ||
        fail "pre-commit, secret and syntax error" "exit status $status: $output"
    [[ $output != *"$token"* ]] || fail "pre-commit, secret and syntax error" "the output prints a secret"
    pass "pre-commit blocks a secret and a syntax error in a file found by its shebang"

    if command -v shellcheck >/dev/null; then
        # Empty the index without touching the working tree, so only warn.sh is staged.
        git -C "$repo" read-tree --empty
        cat >"$repo/warn.sh" <<'SCRIPT'
#!/usr/bin/env bash
echo $1
SCRIPT
        git -C "$repo" add warn.sh
        status=0
        output=$(run_hook "$home" "$repo") || status=$?
        [[ $status -eq 1 && $output == *'warn.sh'* && $output == *SC2086* && $output == *'failed: shellcheck'* ]] ||
            fail "pre-commit, shellcheck" "exit status $status: $output"
        pass "pre-commit blocks shellcheck warnings"
    else
        skip "pre-commit, shellcheck" "shellcheck is not installed"
    fi

    git -C "$repo" read-tree --empty
    printf 'notes\n' >"$repo/notes.txt"
    git -C "$repo" add notes.txt
    status=0
    output=$(run_hook "$home" "$repo" SKIP=check-yaml) || status=$?
    [[ $status -eq 0 && $(<"$home/pre-commit.log") == 'run --hook-stage pre-commit SKIP=shellcheck,check-yaml' ]] ||
        fail "pre-commit, pre-commit run" "exit status $status: $output; ran: $(<"$home/pre-commit.log")"
    status=0
    output=$(run_hook "$home" "$repo" STUB_STATUS=1) || status=$?
    [[ $status -eq 1 && $output == *'failed: pre-commit run'* ]] ||
        fail "pre-commit, pre-commit run" "exit status $status: $output"
    pass "pre-commit runs pre-commit without its ShellCheck hook, and blocks when it fails"

    rm "$home/bin/pre-commit"
    if ! command -v pre-commit >/dev/null; then
        status=0
        output=$(run_hook "$home" "$repo") || status=$?
        [[ $status -eq 0 && $output == *'pre-commit is not installed'* ]] ||
            fail "pre-commit, no pre-commit" "exit status $status: $output"
        pass "pre-commit skips pre-commit when it is not installed"
    else
        skip "pre-commit, no pre-commit" "pre-commit is installed"
    fi
}

# run_installer HOME STUBS SCRIPT [VAR=value...] [-- ARG...] prints the output of an
# install script run with HOME, the stub curl first on PATH, and LOG in HOME, and
# returns its status.
run_installer() {
    local home=$1 stubs=$2 script=$3
    local -a vars=()
    shift 3
    while [[ $# -gt 0 && $1 != -- ]]; do
        vars+=("$1")
        shift
    done
    [[ ${1-} != -- ]] || shift
    env -i HOME="$home" PATH="$stubs:/usr/bin:/bin" LOG="$home/log" ${vars[@]+"${vars[@]}"} \
        "$BASH" "$REPO/home/.local/share/helpers/sh/$script" "$@" 2>&1
}

# The install helpers ignore ~/.curlrc, download to a file before running
# anything, stop on a failed download or one that is not a script, and put files
# where they say. install-dotnet.sh turns its optional first argument into
# --channel or --version, and rejects an unknown one, or one given with
# --channel or --version, before downloading. A stub curl serves fake installers
# that log their arguments, so nothing is downloaded.
check_install_scripts() {
    local home stubs status output pair
    home=$(new_home)
    stubs="$home/stubs"
    mkdir "$stubs"
    cat >"$stubs/curl" <<'STUB'
#!/usr/bin/env bash
# Copies $CURL_SOURCE to the --output file, or fails like `curl --fail` on a 404.
# --disable must come first, so the user's ~/.curlrc cannot change the download.
if [[ ${1-} != --disable ]]; then echo 'curl: called without --disable first' >&2; exit 2; fi
out=''
while [[ $# -gt 0 ]]; do
    if [[ $1 == --output ]]; then out=$2; shift; fi
    shift
done
if [[ -n ${CURL_FAIL-} ]]; then echo 'curl: (22) The requested URL returned error: 404' >&2; exit 22; fi
cp "$CURL_SOURCE" "$out"
STUB
    cat >"$stubs/omp-installer.sh" <<'STUB'
#!/usr/bin/env bash
# Like the real installer, refuses a -d directory that does not exist.
printf 'installer %s\n' "$*" >>"$LOG"
[[ -d $2 ]] || exit 1
printf '#!/usr/bin/env bash\nprintf "oh-my-posh %%s\\n" "$*" >>"$LOG"\n' >"$2/oh-my-posh"
chmod +x "$2/oh-my-posh"
STUB
    cat >"$stubs/dotnet-installer.sh" <<'STUB'
#!/usr/bin/env bash
printf 'dotnet-install %s\n' "$*" >>"$LOG"
STUB
    printf '<html>Not Found</html>\n' >"$stubs/error-page.html"
    chmod +x "$stubs/curl"

    status=0
    output=$(run_installer "$home" "$stubs" install-oh-my-posh.sh CURL_SOURCE="$stubs/omp-installer.sh") ||
        status=$?
    [[ $status -eq 0 && $(<"$home/log") == "installer -d $home/.local/bin"$'\n'"oh-my-posh enable reload" ]] ||
        fail "install-oh-my-posh.sh" "exit status $status: $output; log: $(<"$home/log")"
    pass "install-oh-my-posh.sh creates ~/.local/bin, installs, and enables reload once"

    home=$(new_home)
    status=0
    output=$(run_installer "$home" "$stubs" install-oh-my-posh.sh CURL_FAIL=1) || status=$?
    [[ $status -ne 0 && $output == *'could not download'* && ! -e $home/log ]] ||
        fail "install-oh-my-posh.sh, failed download" "exit status $status: $output"
    pass "install-oh-my-posh.sh stops on a failed download without running anything"

    home=$(new_home)
    status=0
    output=$(run_installer "$home" "$stubs" install-dotnet.sh CURL_SOURCE="$stubs/dotnet-installer.sh") ||
        status=$?
    [[ $status -eq 0 && $(<"$home/log") == "dotnet-install --install-dir $home/.dotnet" &&
        -x $home/.dotnet/dotnet-install.sh ]] ||
        fail "install-dotnet.sh" "exit status $status: $output"
    pass "install-dotnet.sh installs into ~/.dotnet"

    home=$(new_home)
    status=0
    output=$(run_installer "$home" "$stubs" install-dotnet.sh CURL_SOURCE="$stubs/dotnet-installer.sh" \
        -- --install-dir "$home/custom") || status=$?
    [[ $status -eq 0 && $(<"$home/log") == "dotnet-install --install-dir $home/custom" &&
        -x $home/custom/dotnet-install.sh && ! -e $home/.dotnet ]] ||
        fail "install-dotnet.sh, --install-dir" "exit status $status: $output; log: $(<"$home/log")"
    pass "install-dotnet.sh honors a custom --install-dir"

    home=$(new_home)
    status=0
    output=$(run_installer "$home" "$stubs" install-dotnet.sh CURL_SOURCE="$stubs/error-page.html") || status=$?
    [[ $status -eq 1 && $output == *'is not a script'* && ! -e $home/log && ! -e $home/.dotnet ]] ||
        fail "install-dotnet.sh, not a script" "exit status $status: $output"
    pass "install-dotnet.sh refuses a download that is not a script"

    # Each pair is a first argument and the options it becomes.
    for pair in 'lts|--channel lts' '10|--channel 10.0' '10.0|--channel 10.0' '10.0.1xx|--channel 10.0.1xx' \
        '10.0.100|--version 10.0.100' '10.0.100-rc.2.25502.107|--version 10.0.100-rc.2.25502.107'; do
        home=$(new_home)
        status=0
        output=$(run_installer "$home" "$stubs" install-dotnet.sh CURL_SOURCE="$stubs/dotnet-installer.sh" \
            -- "${pair%%|*}" --dry-run) || status=$?
        [[ $status -eq 0 && $(<"$home/log") == "dotnet-install --install-dir $home/.dotnet ${pair#*|} --dry-run" ]] ||
            fail "install-dotnet.sh ${pair%%|*}" "exit status $status: $output; log: $(<"$home/log")"
    done
    pass "install-dotnet.sh turns a release into --channel and a version into --version"

    home=$(new_home)
    for pair in '10.0.x|10.0.x is not a release or version' '10.0 --version 10.0.100|give 10.0 or --version, not both'; do
        status=0
        # shellcheck disable=SC2086 # the arguments are split on purpose
        output=$(run_installer "$home" "$stubs" install-dotnet.sh CURL_SOURCE="$stubs/dotnet-installer.sh" \
            -- ${pair%%|*}) || status=$?
        [[ $status -eq 2 && $output == *"${pair#*|}"* && ! -e $home/log ]] ||
            fail "install-dotnet.sh ${pair%%|*}" "exit status $status: $output"
    done
    pass "install-dotnet.sh rejects an unknown release, or one with --channel or --version, before downloading"
}

# run_init_gitconfig HOME TOOLS [ARG...] prints the output of init-gitconfig.sh run
# with HOME in an empty environment whose PATH holds only the stub directories
# TOOLS and the core utilities it needs, so the gpg, gh, and glab installed here
# never change the result, and returns its status.
run_init_gitconfig() {
    local home=$1 tools=$2
    shift 2
    env -i HOME="$home" PATH="$tools:$TEST_ROOT/gitconfig/core" \
        "$BASH" "$REPO/home/.local/share/helpers/sh/init-gitconfig.sh" "$@" 2>&1
}

# init-gitconfig.sh creates a starter ~/.gitconfig, after which `git config
# --global` writes there instead of the linked ~/.config/git/config. The starter
# sets nothing on a machine without a usable gpg secret key, gh, or glab, and
# turns each on when it is ready, naming a tool by its path unless the path needs
# quoting; gpg is never run without a GnuPG home. An existing ~/.gitconfig or a
# symlink in its place is left unchanged unless --force moves it to an unused
# backup name first. --dry-run changes nothing, and an unknown argument is a
# usage error. Stubs stand in for gpg (listing the keys in HOME/keys), gh, glab,
# and date (fixing the backup name).
check_init_gitconfig() {
    local home other output status git dir cmd tools none spaced fixed expected backup
    if ! command -v git >/dev/null; then
        skip "init-gitconfig.sh" "git is not installed"
        return
    fi
    git=$(command -v git)
    dir="$TEST_ROOT/gitconfig"
    tools="$dir/tools"
    none="$dir/none"
    spaced="$dir/spaced tools"
    fixed="$dir/fixed-date"
    mkdir -p "$dir/core" "$tools" "$none" "$spaced" "$fixed"
    for cmd in awk bash cat date mv; do
        ln -s "$(command -v "$cmd")" "$dir/core/$cmd"
    done
    cat >"$tools/gpg" <<'STUB'
#!/usr/bin/env bash
printf 'gpg %s\n' "$*" >>"$HOME/gpg.log"
cat "$HOME/keys" 2>/dev/null || true
STUB
    printf '#!/usr/bin/env bash\n' >"$tools/gh"
    cp "$tools/gh" "$tools/glab"
    cp "$tools/gh" "$spaced/gh"
    printf '#!/usr/bin/env bash\nprintf "20260102-030405\\n"\n' >"$fixed/date"
    chmod +x "$tools/gpg" "$tools/gh" "$tools/glab" "$spaced/gh" "$fixed/date"

    home=$(new_home)
    mkdir -p "$home/.config/git"
    cp "$REPO/home/.config/git/config" "$home/.config/git/config"
    expected="Would create $home/.gitconfig with:
  commit signing: off until gpg has a secret key
  github.com and gist.github.com credentials: off; gh is not installed
  gitlab.com credentials: off; glab is not installed"
    status=0
    output=$(run_init_gitconfig "$home" "$none" --dry-run) || status=$?
    [[ $status -eq 0 && $output == "$expected" && ! -e $home/.gitconfig ]] ||
        fail "init-gitconfig.sh --dry-run" "exit status $status: $output"
    status=0
    output=$(run_init_gitconfig "$home" "$none" --bogus) || status=$?
    [[ $status -eq 2 && ! -e $home/.gitconfig ]] || fail "init-gitconfig.sh, usage" "exit status $status: $output"
    pass "init-gitconfig.sh --dry-run creates nothing, and a bad argument is a usage error"

    status=0
    output=$(run_init_gitconfig "$home" "$none") || status=$?
    [[ $status -eq 0 && -f $home/.gitconfig && ! -L $home/.gitconfig ]] ||
        fail "init-gitconfig.sh, create" "exit status $status: $output"
    output=$("$git" config --file "$home/.gitconfig" --list 2>&1) ||
        fail "init-gitconfig.sh, create" "Git cannot read the starter file: $output"
    [[ -z $output ]] || fail "init-gitconfig.sh, create" "the starter file sets: $output"
    env -i HOME="$home" PATH="${git%/*}" GIT_CONFIG_NOSYSTEM=1 "$git" config --global user.name Tester
    if [[ $("$git" config --file "$home/.gitconfig" user.name) != Tester ]] ||
        ! cmp -s "$REPO/home/.config/git/config" "$home/.config/git/config"; then
        fail "init-gitconfig.sh, create" "git config --global did not write to ~/.gitconfig"
    fi
    pass "init-gitconfig.sh creates a starter ~/.gitconfig, setting nothing without gpg keys, gh, or glab, that git config --global writes to"

    other=$(new_home)
    mkdir "$other/.gnupg"
    printf 'sec:u:255:22:0123456789ABCDEF:1700000000:::u:::scESC:::+:::23::0:\n' >"$other/keys"
    expected="commit.gpgsign=true
gpg.program=$tools/gpg
credential.https://github.com.helper=
credential.https://github.com.helper=!$tools/gh auth git-credential
credential.https://gist.github.com.helper=
credential.https://gist.github.com.helper=!$tools/gh auth git-credential
credential.https://gitlab.com.helper=
credential.https://gitlab.com.helper=!$tools/glab auth git-credential"
    status=0
    output=$(run_init_gitconfig "$other" "$tools") || status=$?
    [[ $status -eq 0 && $("$git" config --file "$other/.gitconfig" --list 2>&1) == "$expected" ]] ||
        fail "init-gitconfig.sh, ready tools" "exit status $status: $output; file: $(cat "$other/.gitconfig")"
    pass "init-gitconfig.sh turns on signing with a secret key, and gh and glab credentials when installed"

    other=$(new_home)
    mkdir "$other/.gnupg"
    printf 'sec:e:255:22:0123456789ABCDEF:1600000000:1650000000::u:::scESC:::+:::23::0:\n' >"$other/keys"
    expected="credential.https://github.com.helper=
credential.https://github.com.helper=!gh auth git-credential
credential.https://gist.github.com.helper=
credential.https://gist.github.com.helper=!gh auth git-credential
credential.https://gitlab.com.helper=
credential.https://gitlab.com.helper=!$tools/glab auth git-credential"
    status=0
    output=$(run_init_gitconfig "$other" "$spaced:$tools") || status=$?
    [[ $status -eq 0 && $("$git" config --file "$other/.gitconfig" --list 2>&1) == "$expected" ]] ||
        fail "init-gitconfig.sh, expired key" "exit status $status: $output; file: $(cat "$other/.gitconfig")"
    other=$(new_home)
    status=0
    output=$(run_init_gitconfig "$other" "$tools" --dry-run) || status=$?
    [[ $status -eq 0 && $output == *'commit signing: off'* && ! -e $other/gpg.log ]] ||
        fail "init-gitconfig.sh, no GnuPG home" "exit status $status: $output"
    pass "init-gitconfig.sh skips an expired key, runs no gpg without a GnuPG home, and names a tool whose path needs quoting"

    cp "$home/.gitconfig" "$home/before"
    status=0
    output=$(run_init_gitconfig "$home" "$tools") || status=$?
    if [[ $status -ne 0 || $output != *'exists; leaving it unchanged'* ]] || ! cmp -s "$home/before" "$home/.gitconfig"; then
        fail "init-gitconfig.sh, existing file" "exit status $status: $output"
    fi
    other=$(new_home)
    ln -s "$other/missing" "$other/.gitconfig"
    status=0
    output=$(run_init_gitconfig "$other" "$tools") || status=$?
    [[ $status -eq 0 && -L $other/.gitconfig && ! -e $other/missing ]] ||
        fail "init-gitconfig.sh, symlink" "exit status $status: $output"
    pass "init-gitconfig.sh leaves an existing ~/.gitconfig or a symlink unchanged"

    backup="$home/.gitconfig.bak.20260102-030405"
    status=0
    output=$(run_init_gitconfig "$home" "$fixed" --dry-run --force) || status=$?
    if [[ $status -ne 0 || $output != "Would move $home/.gitconfig to $backup."* || -e $backup ]] ||
        ! cmp -s "$home/before" "$home/.gitconfig"; then
        fail "init-gitconfig.sh --dry-run --force" "exit status $status: $output"
    fi
    : >"$backup"
    status=0
    output=$(run_init_gitconfig "$home" "$fixed" --force) || status=$?
    if [[ $status -ne 0 || ! -f $home/.gitconfig || -n $("$git" config --file "$home/.gitconfig" --list 2>&1) ]] ||
        ! cmp -s "$home/before" "$backup.1"; then
        fail "init-gitconfig.sh --force" "exit status $status: $output"
    fi
    other=$(new_home)
    printf '[user]\n\tname = Linked\n' >"$other/target"
    ln -s "$other/target" "$other/.gitconfig"
    status=0
    output=$(run_init_gitconfig "$other" "$fixed" --force) || status=$?
    [[ $status -eq 0 && -L $other/.gitconfig.bak.20260102-030405 && -f $other/.gitconfig && ! -L $other/.gitconfig &&
        $(cat "$other/target") == *'name = Linked' ]] ||
        fail "init-gitconfig.sh --force, symlink" "exit status $status: $output"
    pass "init-gitconfig.sh --force moves the old file or symlink to an unused backup name, then writes a fresh starter"
}

# .bash_logout clears a virtual console as its outermost shell exits, with
# clear_console when present, and leaves other terminals (pts), nested shells,
# and systems without `tty` alone. It runs ~/.bash_logout.local when present.
# The tty, clear, and clear_console stubs report what ran.
check_bash_logout() {
    local home
    home=$(new_home)
    expect ".bash_logout clears only a console's outermost shell" 'clear|clear_console -q|||local' \
        "$home" -- "$REPO/home/.bash_logout" <<'BASH'
clear() { printf clear; }
tty() { printf '/dev/tty3\n'; }
source "$1"
printf '|'
clear_console() { printf 'clear_console %s' "$*"; }
source "$1"
printf '|'
unset -f clear_console
tty() { printf '/dev/pts/0\n'; }
source "$1"
printf '|'
unset -f tty
source "$1"
printf '|'
printf 'printf local\n' >"$HOME/.bash_logout.local"
source "$1"
BASH
    home=$(new_home)
    expect ".bash_logout, nested shell" '' "$home" SHLVL=1 -- "$REPO/home/.bash_logout" <<'BASH'
clear() { printf clear; }
tty() { printf '/dev/tty3\n'; }
source "$1"
BASH
}

# dotnet.sh puts a user install in ~/.dotnet first on PATH and its global tools
# last, once each, and sets DOTNET_ROOT, even when sourced twice.
check_dotnet_path() {
    local home
    home=$(new_home)
    mkdir -p "$home/.dotnet/tools"
    : >"$home/.dotnet/dotnet"
    chmod +x "$home/.dotnet/dotnet"
    expect "dotnet.sh PATH, user install" \
        "$home/.dotnet:/nonexistent:$home/.dotnet/tools $home/.dotnet" \
        "$home" -- "$REPO/home/.bashrc.d/dotnet.sh" <<'BASH'
for attempt in 1 2; do
    source "$1"
done
printf '%s %s' "$PATH" "$DOTNET_ROOT"
BASH
}

# render_prompt THEME HOME DIR WIDTH prints the prompt that oh-my-posh renders
# from the theme file THEME with HOME for the directory DIR at WIDTH columns,
# without colors (--plain), and returns its status. env -i keeps out a live Oh My
# Posh session, whose cached config would otherwise be rendered in place of --config.
render_prompt() {
    env -i HOME="$2" PATH="$PATH" LANG=en_US.UTF-8 TERM=xterm-256color \
        oh-my-posh print primary --config "$1" --shell bash --plain --pwd "$3" --terminal-width "$4" 2>&1
}

# Every theme except jandedobbeleer, which stays identical to upstream, starts its
# top line with the date and time on a 12-hour clock, preceded only by glyphs or
# brackets, and shows the directory on that line; a theme with a right-aligned
# part moves that part to a line of its own when the terminal is too narrow for
# both. Runs when oh-my-posh is installed. A template error would print in place
# of the time (with a stray % or none at all).
check_prompt_themes() {
    local home dir theme name output status top
    local clock='^[^[:alnum:]]*[A-Z][a-z]{2} [A-Z][a-z]{2} [ 0-9][0-9] [0-9]{2}:[0-9]{2}:[0-9]{2} (AM|PM) [^ ]+ [0-9]{4}'
    if ! command -v oh-my-posh >/dev/null; then
        skip "oh-my-posh themes render" "oh-my-posh is not installed"
        return
    fi
    home=$(new_home)
    dir="$home/prompt-dir"
    mkdir "$dir"
    for theme in "$REPO"/home/.config/oh-my-posh/themes/*.omp.json; do
        name=${theme##*/}
        name=${name%.omp.json}
        [[ $name != jandedobbeleer ]] || continue
        status=0
        output=$(render_prompt "$theme" "$home" "$dir" 120) || status=$?
        top=${output%%$'\n'*}
        [[ $status -eq 0 && $output != *'%'* && $top =~ $clock && $top == *prompt-dir* ]] ||
            fail "$name theme" "the clock does not lead the top line (exit status $status): $output"
        if grep -q '"alignment": "right"' "$theme"; then
            status=0
            output=$(render_prompt "$theme" "$home" "$dir" 50) || status=$?
            top=${output%%$'\n'*}
            [[ $status -eq 0 && $top =~ $clock && $top != *prompt-dir* && $output == *prompt-dir* ]] ||
                fail "$name theme, narrow terminal" "exit status $status: $output"
        fi
        pass "$name theme starts its top line with the date and time"
    done
}

# oh-my-posh.sh uses the theme named by OHMYPOSH_THEME: bubblesextra by default,
# another theme by name, or any theme file by path, and leaves the plain prompt
# when the theme is missing. A value set in ~/.bashrc.d/local.sh applies, because
# local.sh loads first. A stub oh-my-posh prints the theme it is given, and the
# interactive-only guard is removed, because the sandbox shell is not interactive.
check_theme_selection() {
    local home themes
    home=$(new_home)
    themes="$home/.config/oh-my-posh/themes"
    mkdir -p "$themes" "$home/custom" "$home/.bashrc.d"
    : >"$themes/bubblesextra.omp.json"
    : >"$themes/jandedobbeleer.omp.json"
    : >"$themes/bubbles.omp.json"
    : >"$home/custom/mine.omp.json"
    "$SED_BIN" 's/\[\[ \$- == \*i\* \]\] && //' "$REPO/home/.bashrc.d/oh-my-posh.sh" \
        >"$home/.bashrc.d/oh-my-posh.sh"
    printf 'OHMYPOSH_THEME=bubbles\n' >"$home/.bashrc.d/local.sh"
    expect "oh-my-posh.sh theme selection" \
        "$themes/bubblesextra.omp.json|$themes/jandedobbeleer.omp.json|$home/custom/mine.omp.json||$themes/bubbles.omp.json" \
        "$home" -- "$REPO/home/.bashrc" "$SED_BIN" <<'BASH'
oh-my-posh() { printf 'printf %%s %q' "$4"; }
for theme in '' jandedobbeleer "$HOME/custom/mine.omp.json" missing; do
    OHMYPOSH_THEME=$theme
    source "$HOME/.bashrc.d/oh-my-posh.sh"
    printf '|'
done
unset OHMYPOSH_THEME
source <("$2" -n '/^# User specific environment$/,$p' "$1")
BASH
}

# .vimrc and tmux.conf load without errors, when vim and tmux are installed, and
# .vimrc sets its ruler (colorcolumn) to column 120.
check_editor_configs() {
    local home output status
    home=$(new_home)
    if command -v vim >/dev/null; then
        status=0
        output=$(HOME="$home" vim -N -u "$REPO/home/.vimrc" -i NONE -n -es \
            -c 'if v:errmsg != "" | cquit | endif' \
            -c 'call writefile([&colorcolumn], "/dev/stdout")' -c 'qa!' 2>&1) || status=$?
        [[ $status -eq 0 && $output == 120 ]] || fail ".vimrc loads" "exit status $status: $output"
        pass ".vimrc loads, with its ruler at column 120"
    else
        skip ".vimrc loads" "vim is not installed"
    fi
    if command -v tmux >/dev/null; then
        status=0
        # A named server (-L) keeps the socket path short and apart from real sessions.
        # tmux exits 0 even after an invalid option, printing only a message, so the
        # output must be exactly the prefix that the file sets.
        output=$(tmux -L "dotfiles-check-$$" -f /dev/null start-server \; \
            source-file "$REPO/home/.config/tmux/tmux.conf" \; show-options -gv prefix \; \
            kill-server 2>&1) || status=$?
        [[ $status -eq 0 && $output == C-a ]] ||
            fail "tmux.conf loads" "exit status $status: $output"
        pass "tmux.conf loads"
    else
        skip "tmux.conf loads" "tmux is not installed"
    fi
}

# tmux.conf sets the terminal title to start with "tmux", and turns a window's tab
# red while any of its panes runs a privilege tool in the foreground, leaving
# other tabs as tmux draws them. Copies of sleep named sudo and su stand in for
# the tools: sudo in a window's only pane, su in a split pane that is not the
# active one. Runs when tmux is installed.
check_tmux_status() {
    local dir socket tool attempt tabs plain sudo_tab su_tab titles title
    if ! command -v tmux >/dev/null; then
        skip "tmux status" "tmux is not installed"
        return
    fi
    dir="$TEST_ROOT/tmux-tools"
    mkdir -p "$dir"
    for tool in sudo su; do
        cp "$(command -v sleep)" "$dir/$tool"
    done
    # A named server (-L) keeps the test apart from real sessions.
    socket="dotfiles-check-tabs-$$"
    tmux -L "$socket" -f "$REPO/home/.config/tmux/tmux.conf" \
        new-session -d -s check -x 160 -y 40 "sleep 30" \; \
        new-window -d -t check:2 "$dir/sudo 30" \; \
        new-window -d -t check:3 "sleep 30" \; \
        split-window -d -t check:3 "$dir/su 30" ||
        fail "tmux tabs" "could not start a tmux server"
    # The panes' programs start after tmux returns; wait until they run.
    for ((attempt = 0; attempt < 50; attempt++)); do
        [[ $(tmux -L "$socket" display -p -t check:3 '#{P:#{pane_current_command} }') == 'sleep su ' &&
            $(tmux -L "$socket" display -p -t check:2 '#{pane_current_command}') == sudo ]] && break
        sleep 0.1
    done
    tabs=$(tmux -L "$socket" display -p -t check:1 '#{E:window-status-format}' \; \
        display -p -t check:2 '#{E:window-status-format}' \; \
        display -p -t check:3 '#{E:window-status-current-format}' 2>&1)
    titles=$(tmux -L "$socket" show-options -gv set-titles 2>&1)
    title=$(tmux -L "$socket" display -p -t check:1 '#{E:set-titles-string}' 2>&1)
    tmux -L "$socket" kill-server 2>/dev/null || true
    [[ $titles == on && $title == 'tmux: check:1:'* ]] ||
        fail "tmux title" "set-titles '$titles', title '$title'"
    pass "tmux sets the terminal title, starting with tmux"
    plain=$(sed -n 1p <<<"$tabs")
    sudo_tab=$(sed -n 2p <<<"$tabs")
    su_tab=$(sed -n 3p <<<"$tabs")
    [[ $plain != *'bg=red'* && $sudo_tab == '#[bg=red,fg=white,bold]2:'* && $su_tab == '#[bg=red,fg=white,bold]3:'* ]] ||
        fail "tmux tabs" "unexpected tabs: $tabs"
    pass "tmux turns a window's tab red while a pane runs sudo or su"
}

# history.sh sets the history options and adds `history -a` to PROMPT_COMMAND as
# an entry of its own, once, even when sourced twice: after a plain string and
# after an array such as oh-my-posh's, whose entries must stay untouched.
check_history() {
    local home
    home=$(new_home)
    expect "history.sh settings" \
        '50000|100000|ignoreboth:erasedups|%F %T |on|existing;history -a|_omp_hook;other;history -a' \
        "$home" PROMPT_COMMAND=existing -- "$REPO/home/.bashrc.d/history.sh" <<'BASH'
join() { local IFS=';'; printf '%s' "$*"; }
for attempt in 1 2; do
    source "$1"
done
histappend=off
if shopt -q histappend; then histappend=on; fi
printf '%s|%s|%s|%s|%s|%s' "$HISTSIZE" "$HISTFILESIZE" "$HISTCONTROL" "$HISTTIMEFORMAT" \
    "$histappend" "$(join "${PROMPT_COMMAND[@]}")"
PROMPT_COMMAND=(_omp_hook other)
for attempt in 1 2; do
    source "$1"
done
printf '|%s' "$(join "${PROMPT_COMMAND[@]}")"
BASH
}

# .bashrc appends the helpers directory once, after everything else on PATH, so
# a helper never shadows another command, even when sourced twice.
check_helpers_path() {
    local home
    home=$(new_home)
    mkdir -p "$home/.local/share/helpers/sh"
    expect ".bashrc PATH, helpers last" \
        "$home/.local/bin:$home/bin:/nonexistent:$home/.local/share/helpers/sh" \
        "$home" -- "$REPO/home/.bashrc" "$SED_BIN" <<'BASH'
for attempt in 1 2; do
    source <("$2" -n '/^# User specific environment$/,$p' "$1")
done
printf '%s' "$PATH"
BASH
}

# gcp.sh prepends an archive install's bin directory once, even when sourced twice.
check_gcloud_path() {
    local home
    home=$(new_home)
    mkdir -p "$home/google-cloud-sdk/bin"
    expect "gcp.sh PATH, archive install" "$home/google-cloud-sdk/bin:/nonexistent" \
        "$home" -- "$REPO/home/.bashrc.d/gcp.sh" <<'BASH'
for attempt in 1 2; do
    source "$1"
done
printf '%s' "$PATH"
BASH
}

# Link, relink, status, and unlink every file under home/ in an empty home, then
# dry-run the setup steps.
check_manager_integration() {
    local home setup_home completion_home path state
    local -a paths=()
    home=$(new_home)
    # The expected links are every file under home/, found the way homeskillet
    # discovers them (skipping .DS_Store and .git), so nothing here lists them.
    while IFS= read -r -d '' path; do
        paths+=("${path#"$REPO/home/"}")
    done < <(find "$REPO/home" -name .git -prune -o \( -type f -o -type l \) ! -name .DS_Store -print0)
    [[ ${#paths[@]} -gt 0 ]] || fail "link" "no files found under $REPO/home"

    manage "$home" link --dry-run
    [[ -z $(ls -A "$home") ]] || fail "link --dry-run" "it changed the test home"
    pass "link --dry-run changes nothing"

    manage "$home" link
    manage "$home" link
    for path in "${paths[@]}"; do
        [[ -L $home/$path && $(readlink "$home/$path") == "$REPO/home/$path" ]] ||
            fail "link" "$path does not link to $REPO/home/$path"
    done
    pass "link links every file under home/ and is idempotent"

    manage "$home" status
    while IFS=$'\t' read -r state _; do
        [[ $state == linked ]] || fail "status" "unexpected state '$state'"
    done <<<"$MANAGER_OUTPUT"
    pass "status reports every file linked"

    manage "$home" unlink
    for path in "${paths[@]}"; do
        [[ ! -e $home/$path && ! -L $home/$path ]] || fail "unlink" "$path remains"
    done
    pass "unlink removes every link"

    # unlink leaves parent directories behind, so the dry run gets a fresh home.
    setup_home=$(new_home)
    manage "$setup_home" setup --dry-run
    [[ -z $(ls -A "$setup_home") ]] || fail "setup --dry-run" "it changed the test home"
    pass "setup --dry-run succeeds and changes nothing"

    # homeskillet.sh, its interactive-only guard removed, loads the manager's own
    # completion, which completes its commands and this repository's setup step
    # names; each name offered must be one dotfiles.json declares, so nothing here
    # lists them.
    completion_home=$(new_home)
    mkdir -p "$completion_home/bin"
    ln -s "$MANAGER" "$completion_home/bin/homeskillet"
    expect "homeskillet completion through the manager" 'link|steps' "$completion_home" \
        PATH="$completion_home/bin:/usr/bin:/bin" -- \
        "$REPO/home/.bashrc.d/homeskillet.sh" "$REPO" "$SED_BIN" <<'BASH'
source <("$3" 's/\[\[ \$- == \*i\* \]\] && //' "$1")
complete_words() {
    COMP_WORDS=("$@")
    COMP_CWORD=$((${#COMP_WORDS[@]} - 1))
    _homeskillet
}
complete_words homeskillet li
printf '%s|' "${COMPREPLY[*]}"
complete_words homeskillet setup --repo "$2" ''
for step in "${COMPREPLY[@]}"; do
    grep -q "\"name\": \"$step\"" "$2/dotfiles.json" || printf 'not a step: %s|' "$step"
done
if ((${#COMPREPLY[@]})); then printf steps; fi
BASH
}

# Main entry point for the test script. Parses arguments, sets up the environment,
# and runs the shell checks, then the manager checks when a manager is given.
main() {
    case $# in
        0) ;;
        1)
            if [[ $1 == -h || $1 == --help ]]; then
                usage
                return
            fi
            MANAGER=$(command -v -- "$1") || die "manager not found or not executable: $1"
            [[ -f $MANAGER && -x $MANAGER ]] || die "manager is not an executable file: $1"
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
    setup

    check_shell_path
    check_terminal_settings
    check_bash_logout
    check_snippets_without_tools
    check_completion_files
    check_homeskillet_completion
    check_completion_loading
    check_aws_region
    check_telemetry_defaults
    check_history
    check_helpers_path
    check_gcloud_path
    check_dotnet_path
    check_functions
    check_secret_scan
    check_pre_commit_hook
    check_install_scripts
    check_init_gitconfig
    check_theme_selection
    check_editor_configs
    check_tmux_status
    check_prompt_themes
    printf 'Shell regression checks passed.\n'

    if [[ -n $MANAGER ]]; then
        check_manager_integration
        printf 'Manager integration checks passed.\n'
    fi
}
# Invoke the main function with all script arguments.
main "$@"
