#!/usr/bin/env bash
# Refuses secrets and personal details in this repository.
#
# Usage: bash scripts/check-secrets.sh [--staged | --all]
#
# --staged (the default, run by .githooks/pre-commit) checks what the next commit
# would add; --all checks every tracked file, as CI does. It reports:
#   - files that .gitignore ignores but were added anyway with `git add -f`
#   - private keys and tokens with a recognizable form (AWS, GitHub, GitLab,
#     Slack, Google, Stripe, npm, PyPI, Anthropic)
#   - the current home directory path and Git email, so nothing machine-specific
#     is committed
# Findings name the file and line but never print the match, which may be the
# secret itself. A line containing `secret-scan: allow` is skipped: use it only
# for a reviewed false positive. Exit status: 0 clean, 1 findings, 2 usage error.
set -euo pipefail
# CDPATH can redirect cd to another directory and make it print the path.
unset CDPATH

# Global variables
readonly ALLOW_MARKER='secret-scan: allow'
# Rule names and the extended regular expressions they match, index for index.
readonly -a RULE_NAMES=(
    'private key'
    'AWS access key ID'
    'AWS secret access key'
    'GitHub token'
    'GitHub fine-grained token'
    'GitLab token'
    'Slack token'
    'Google API key'
    'Stripe live key'
    'npm token'
    'PyPI token'
    'Anthropic API key'
)
readonly -a RULE_PATTERNS=(
    '-----BEGIN ([A-Z0-9]+ )*PRIVATE KEY( BLOCK)?-----'
    '(^|[^0-9A-Z])(AKIA|ASIA)[0-9A-Z]{16}([^0-9A-Z]|$)'
    "(aws|AWS)_(secret|SECRET)_(access|ACCESS)_(key|KEY)[[:space:]]*[=:][[:space:]]*[\"']?[A-Za-z0-9/+]{40}"
    'gh[pousr]_[A-Za-z0-9]{36}'
    'github_pat_[A-Za-z0-9_]{60,}'
    'glpat-[A-Za-z0-9_-]{20,}'
    'xox[abprs]-[A-Za-z0-9-]{10,}'
    'AIza[0-9A-Za-z_-]{35}'
    '[rs]k_live_[0-9A-Za-z]{24,}'
    'npm_[A-Za-z0-9]{36}'
    'pypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}'
    'sk-ant-[A-Za-z0-9_-]{20,}'
)
FINDINGS=0
TMP_DIR=''

# usage prints how to run the script.
usage() {
    printf 'Usage: bash scripts/check-secrets.sh [--staged | --all]\n'
}

# die prints an error message and exits with status 2.
die() {
    printf 'check-secrets.sh: %s\n' "$1" >&2
    exit 2
}

# cleanup removes the temporary directory if it exists.
cleanup() {
    if [[ -n $TMP_DIR && -d $TMP_DIR ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}

# report prints one finding as PATH:LINE: REASON, or PATH: REASON for a whole
# file, without the matched text.
report() {
    if [[ -n $2 ]]; then
        printf '%s:%s: %s\n' "$1" "$2" "$3" >&2
    else
        printf '%s: %s\n' "$1" "$3" >&2
    fi
    FINDINGS=$((FINDINGS + 1))
}

# check_ignored reports files that .gitignore ignores but are staged or tracked
# anyway. A path matched by a negated (!) pattern is an explicit exception.
check_ignored() {
    local results="$TMP_DIR/ignored" status=0 source line pattern path
    printf '%s\0' "$@" | git check-ignore --no-index --verbose -z --stdin >"$results" || status=$?
    [[ $status -le 1 ]] || die "git check-ignore failed with status $status"
    while IFS= read -r -d '' source && IFS= read -r -d '' line &&
        IFS= read -r -d '' pattern && IFS= read -r -d '' path; do
        if [[ $pattern != '!'* ]]; then
            report "$path" '' "ignored by $source:$line ($pattern); unstage it, or add a !$path exception"
        fi
    done <"$results"
}

# scan REASON MODE PATTERN PATH... reports each staged line in PATH... that
# matches PATTERN, a regular expression (MODE -E) or fixed string (MODE -F).
# Binary files are skipped; check_ignored covers key files by name.
scan() {
    local reason=$1 mode=$2 pattern=$3 results="$TMP_DIR/matches" status=0 path line content
    shift 3
    # Literal pathspecs keep a file named like a[1] from matching as a glob.
    git --literal-pathspecs grep --cached -I -n -z "$mode" -e "$pattern" -- "$@" >"$results" || status=$?
    [[ $status -le 1 ]] || die "git grep failed with status $status while checking: $reason"
    while IFS= read -r -d '' path && IFS= read -r -d '' line && IFS= read -r content; do
        if [[ $content != *"$ALLOW_MARKER"* ]]; then
            report "$path" "$line" "$reason"
        fi
    done <"$results"
}

# check_personal reports the current home directory path and Git email.
check_personal() {
    local email
    if [[ -n ${HOME-} && $HOME != / ]]; then
        scan 'home directory path' -F "$HOME" "$@"
    fi
    email=$(git config --get user.email || true)
    if [[ -n $email ]]; then
        scan 'Git user email' -F "$email" "$@"
    fi
}

# main lists the files to check for the chosen mode and runs every check.
main() {
    local mode=--staged path i
    local -a paths=()
    case $# in
        0) ;;
        1) mode=$1 ;;
        *) usage >&2 && exit 2 ;;
    esac
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a Git work tree"
    cd -- "$(git rev-parse --show-toplevel)"
    case $mode in
        -h | --help)
            usage
            return 0
            ;;
        --staged)
            while IFS= read -r -d '' path; do
                paths+=("$path")
            done < <(git diff --cached --name-only --diff-filter=ACMR -z)
            ;;
        --all)
            while IFS= read -r -d '' path; do
                paths+=("$path")
            done < <(git ls-files -z)
            ;;
        *) usage >&2 && exit 2 ;;
    esac
    [[ ${#paths[@]} -gt 0 ]] || return 0

    trap cleanup EXIT
    TMP_DIR=$(mktemp -d)
    check_ignored "${paths[@]}"
    for i in "${!RULE_PATTERNS[@]}"; do
        scan "${RULE_NAMES[i]}" -E "${RULE_PATTERNS[i]}" "${paths[@]}"
    done
    check_personal "${paths[@]}"

    if [[ $FINDINGS -gt 0 ]]; then
        printf '%d finding(s). Remove each one; for a reviewed false positive, add a "%s" comment on its line.\n' \
            "$FINDINGS" "$ALLOW_MARKER" >&2
        exit 1
    fi
}
# Execute the main function with all command-line arguments.
main "$@"
