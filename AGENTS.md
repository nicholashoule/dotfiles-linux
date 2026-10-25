# Contributor Guide

Conventions for changing this repository, for people and coding agents alike.
[README.md](README.md) describes what the configuration does; this file says how
to change it without breaking its guarantees.

## Scope

- Bash on Linux only. macOS and zsh live in the separate `dotfiles-macos`
  repository; the manager lives in `homeskillet`.
- Everything meant for the user's home directory lives under `home/`, which
  homeskillet links file by file. Repository tooling (`scripts/`, `tests/`,
  `.githooks/`, CI) stays outside `home/`. Helper commands are called helpers,
  not scripts, and live in `home/.local/share/helpers/sh/`.
- The repository is public. Commit nothing machine-specific: no user names,
  absolute home paths, email addresses, hostnames, tokens, or values copied from
  another project. Use placeholders such as `/path/to/homeskillet` and `$HOME`.
  Turn on the pre-commit hook in every clone (`git config core.hooksPath
  .githooks`); it and CI enforce part of this rule.
- Never put a file under `home/` that tools write personal settings into, such
  as `~/.gitconfig`: writes follow the link into this repository. Create such a
  file once with a setup step and a helper that never replaces an existing file,
  as `init-gitconfig.sh` does, and keep the shared settings in a linked file the
  tool also reads (`~/.config/git/config`).

## Shell Snippets (`home/.bashrc.d/*.sh`)

- One tool per file, starting with `# shellcheck shell=bash`, a title line, and a
  link to the tool's documentation.
- Defaults use `${VAR:-value}` so existing values win. Optional ones stay
  commented out; always-on ones (such as telemetry opt-outs) are explained.
- Run tool commands only when `command -v` finds the tool, and load completions,
  aliases, functions, and the prompt only in interactive shells
  (`[[ $- == *i* ]]`).
- Evaluate generated code only when its generator succeeded, quote `complete -C`
  paths with `printf %q`, keep PATH edits idempotent, and unset helper variables.
- When adding a tool, add its telemetry opt-out if it has one.

## Completions (`home/.local/share/bash-completion/completions/`)

- `.bashrc` loads bash-completion before the snippets; it lazy-loads a file from
  this directory the first time its command is completed. Name each file after
  its command (`name.bash`), start it with `# shellcheck shell=bash` and a
  comment saying what it completes, and register only that command.
- Write plain Bash (`COMP_WORDS`, `COMP_CWORD`, `compgen`, and
  `mapfile -t COMPREPLY`), not bash-completion's helper functions, whose names
  differ between versions. Silence `compopt`, which fails outside completion.
- `compgen -W` expands its word list: give it fixed words, or command output
  filtered to plain values first.
- A tool's own generated completion belongs in its snippet instead, following
  the snippet rules above.

## Functions, Helpers, and Scripts

- Every function has a doc comment above it, `name ARGS` and what it does, and
  declares its local variables at the top.
- Interactive functions check their arguments and the tools they need, and
  return 2 for incorrect use and 127 for a missing tool.
- Helpers (`home/.local/share/helpers/sh/*.sh`, executable) and repository
  scripts (`scripts/`, `tests/`) start with `#!/usr/bin/env bash` and
  `set -euo pipefail`, declare global variables at the top, run from a `main`
  function, and clean temporary directories with a trap.
- Downloads use `curl --disable --fail --proto '=https' --tlsv1.2` (`--disable`
  first, so the user's `~/.curlrc` cannot change them) and go to a file that is
  checked before it runs; never pipe a download into a shell. Installers are
  idempotent and never edit shell startup files.

## Documentation

- Every file starts with a comment saying what it is for, and every function
  with a doc comment. Comments explain why, not only what.
- The README describes every user-visible behavior: what each file under `home/`
  does, its defaults, how to override them (Customize), and how to recover
  (Troubleshooting). Update it in the same change as the behavior.
- Be robust but concise: say what a reader needs to use, change, or debug the
  file, and verify every claim against the code or by running it.
- Never list or count files, steps, or entries; describe sets by rule, such as
  "every file under `home/`", so docs cannot go stale when files are added.
- Keep dotfiles-macos aligned: shared files (`.vimrc`, `tmux.conf`, `.curlrc`,
  `.hushlogin`, the themes, `CODEOWNERS`, Dependabot) stay identical, and the
  rest mirror each other except where zsh or macOS requires a difference.

## Every Change

- Add or update a check in `tests/check.sh` for every behavior change, and
  README coverage for every new file under `home/`. homeskillet links every file
  there, so `dotfiles.json` declares only setup steps.
- A theme added to `home/.config/oh-my-posh/themes/` starts its top line with
  the date and time on a 12-hour clock (`time_format`
  `Mon Jan _2 03:04:05 PM MST 2006`), as every theme except the upstream
  `jandedobbeleer` does; the checks render each theme and enforce it.
- With pre-commit installed, `.githooks/pre-commit` also runs the hygiene checks
  in `.pre-commit-config.yaml` on staged files; run `pre-commit run --all-files`
  to check every file. The hook skips that file's ShellCheck hook by its id,
  `shellcheck`, so keep that id if you replace the hook.
- Before finishing, run:

```sh
bash tests/check.sh /path/to/homeskillet
shellcheck home/.bashrc home/.bash_profile home/.bash_logout home/.bashrc.d/*.sh home/.local/share/helpers/sh/*.sh home/.local/share/bash-completion/completions/* scripts/*.sh tests/check.sh .githooks/pre-commit
bash scripts/check-secrets.sh --all
```
