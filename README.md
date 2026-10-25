# dotfiles-linux

Bash dotfiles for Linux, managed by the separate `homeskillet` CLI. This
repository holds the configuration, its setup steps, and shell checks; the
manager's Go source, tests, and binaries live in the `homeskillet` repository.

## What's Included

- **Shell:** `.bashrc`, `.bash_profile`, and `.bash_logout`, with one snippet
  per tool in `~/.bashrc.d` for AWS, Google Cloud, Go, .NET, kubectl, OpenTofu,
  Terraform, Python with uv, and VS Code, plus history, aliases, and functions.
  Telemetry is off wherever a tool allows it.
- **Completion:** Tab completion through bash-completion on any distribution,
  completions for the snippets' tools and for homeskillet, and a directory for
  your own, loaded on first use.
- **Prompt:** Oh My Posh with the `bubblesextra` theme, showing the path, Git
  state, language versions, battery, and the date and time.
- **Terminal:** Ptyxis and GNOME Terminal set to the prompt's Nerd Font, with
  Ctrl+C and Ctrl+V for copy and paste.
- **Tools:** Git defaults, tmux, vim, and curl settings, and `.hushlogin`.
- **Helpers and setup steps:** a starter `~/.gitconfig` for your identity, and
  reviewed installers for Oh My Posh, its font, and the .NET SDK.
- **Safety:** a pre-commit hook, CI, and `.gitignore` rules that keep secrets
  and personal details out of this public repository, plus regression checks.

## Install

Install `homeskillet` by running `make install` in a checkout of its repository.
It keeps each version under `~/.local/share/homeskillet/versions/` and links
`~/.local/bin/homeskillet` to the active one; this repository's `.bashrc`
already puts `~/.local/bin` on PATH. Go is needed only to build the manager, not
to use this configuration.

```sh
homeskillet version            # version and build details
git pull && make install       # update, run in the homeskillet checkout
homeskillet self use previous  # roll back to the previous version
```

Keep this clone in a permanent location, because installed symlinks point into
it. From the repository root:

```sh
git config core.hooksPath .githooks
homeskillet status --repo .
homeskillet link --repo . --dry-run
homeskillet link --repo .
homeskillet setup --repo .
```

The first command turns on the pre-commit hook that blocks secrets (see
[Secrets](#secrets)); Git needs it once per clone.

`status` is the default command and never changes files. It reports each file
as `missing`, `linked`, `conflict`, or `no-source` (the file is absent from this
repository). Conflicts and missing sources make both `status` and `link` exit
nonzero, so `status` doubles as a check that `link` would succeed. Options
follow the command; from another directory, pass `--repo` with the path to this
clone. Run `homeskillet -h` for every command and option.

Linked files run with your privileges, so `link` refuses a clone that someone
else could modify, much like OpenSSH's StrictModes. The clone and every linked
file must be owned by you and not writable by your group or others, and each
directory above the clone must be owned by you or root and not writable by
others unless it is sticky, like `/tmp`. The manager also refuses to run as root
unless given `--allow-root`, and refuses system directories such as `/`, `/home`,
`/usr`, and `/etc` as the home, repository, or install prefix.

Existing files, directories, and unrelated symlinks are never overwritten.
Before installing, inspect each conflict and move the original into a backup
directory. For example, for an existing `.bashrc`:

```sh
mkdir -p "$HOME/.local/state/dotfiles-backups"
backup=$(mktemp -d "$HOME/.local/state/dotfiles-backups/backup.XXXXXX")
mv -i "$HOME/.bashrc" "$backup/"
```

Repeat for the other conflicts you choose to replace, then run `link` again.
No automatic backup or force-overwrite mode is provided. Existing shells do not
reload automatically; open a new terminal after installation.

## Update and Uninstall

To update, run `git pull` in this clone, then `homeskillet link --repo .` to
link any new files. Changes to files that are already linked take effect at
once, in new shells; there is nothing to reinstall. Update homeskillet itself as
shown under [Install](#install).

To uninstall, unlink, then restore anything you backed up:

```sh
homeskillet unlink --repo . --dry-run
homeskillet unlink --repo .
```

`unlink` removes only the links that point into this clone. Settings that tools
saved outside it stay until you remove them: Go's telemetry choice, Oh My Posh's
auto-reload setting, `~/.vim/undo`, and anything the setup steps installed, such
as `~/.dotnet` or the font in `~/.local/share/fonts`.

## Setup Steps

`homeskillet setup` offers the steps declared in
[dotfiles.json](dotfiles.json). Each one is shown exactly as it will run, from
the repository root with `HOME` set, and runs only if you answer yes; a step is
skipped once the file it `creates` exists or the command it `provides` is on
PATH or in `~/.local/bin`. Steps run with `~/.local/bin` added to the end of
PATH, so a step can use a program that an earlier step installed there, as
`meslo-nerd-font` does with `oh-my-posh`. `homeskillet setup --repo . --dry-run`
lists them without running anything.

| Step | Runs | Done when |
| --- | --- | --- |
| `gitconfig` | [init-gitconfig.sh](home/.local/share/helpers/sh/init-gitconfig.sh): a starter `~/.gitconfig` with commented examples and no settings | `~/.gitconfig` exists |
| `oh-my-posh` | [install-oh-my-posh.sh](home/.local/share/helpers/sh/install-oh-my-posh.sh): the official installer into `~/.local/bin`, then config auto-reload turned on once | `oh-my-posh` is on PATH or in `~/.local/bin` |
| `meslo-nerd-font` | `oh-my-posh font install Meslo` | the font is in `~/.local/share/fonts` |
| `dotnet-sdk` | [install-dotnet.sh](home/.local/share/helpers/sh/install-dotnet.sh): the latest LTS SDK into `~/.dotnet` | `~/.dotnet/dotnet` exists |

The installers download from the internet, so read each step before approving
it. The install helpers save the official installer to a file and stop if the
download fails, instead of piping it into a shell. Once linked,
`install-dotnet.sh` is also a command of its own that passes options through to
Microsoft's `dotnet-install.sh`, for example `--channel 9.0`,
`--install-dir DIR`, or `--dry-run`. Packages from your distribution, such as
`sudo dnf install dotnet-sdk-8.0`, work as well; the snippets handle either kind
of install.

## Helpers

Helper commands live in
[home/.local/share/helpers/sh/](home/.local/share/helpers/sh/) and are linked
into `~/.local/share/helpers/sh/`, which `.bashrc` adds to the end of PATH so a
helper never shadows another command. The setup steps run them from the
repository; afterward they are ordinary commands:

| Helper | Does |
| --- | --- |
| [init-gitconfig.sh](home/.local/share/helpers/sh/init-gitconfig.sh) | Creates a starter `~/.gitconfig` unless one exists, even as a symlink; `--dry-run` only reports |
| [install-dotnet.sh](home/.local/share/helpers/sh/install-dotnet.sh) | Installs a .NET SDK with Microsoft's `dotnet-install.sh`, into `~/.dotnet` unless told otherwise |
| [install-oh-my-posh.sh](home/.local/share/helpers/sh/install-oh-my-posh.sh) | Installs Oh My Posh into `~/.local/bin` and turns on config auto-reload |

## Layout

```text
home/                        linked into your home directory, file by file
  .bashrc  .bash_profile     shell startup
  .bash_logout               login shell logout
  .bashrc.d/                 one snippet per tool, plus aliases and functions
  .config/git/  .config/tmux/  .config/oh-my-posh/themes/
  .local/share/helpers/sh/   helper commands
  .local/share/bash-completion/completions/
                             command completions, loaded on first use
  .curlrc  .hushlogin  .vimrc
dotfiles.json                setup steps for homeskillet
scripts/check-secrets.sh     secret scan, run by the hook and CI
tests/check.sh               regression checks
.githooks/pre-commit         pre-commit hook
.github/                     CI and Dependabot
.pre-commit-config.yaml      optional pre-commit checks
AGENTS.md  CODEOWNERS  LICENSE  .editorconfig  .gitattributes  .gitignore
```

## Manage Files

Everything meant for your home directory lives under `home/`; repository
tooling ([scripts/](scripts/), [tests/](tests/), [.githooks/](.githooks/), and
CI) stays outside it and is never linked. homeskillet links every file under
`home/` to the same path in your home directory, skipping `.DS_Store` and
`.git`; [dotfiles.json](dotfiles.json) declares only the setup steps. Adding a
file under `home/` is all it takes: `home/.config/example/config.toml` becomes
`~/.config/example/config.toml` on the next `link`. Files are linked one by one,
never whole directories such as `.config` or `.bashrc.d`, so other files in those
directories stay yours. Target parent directories that already exist must be
real directories, not symlinks.

Once linked, editing either the home-directory path or the repository file
changes the same file. Review with `git diff`, then commit and push with Git.
On another machine, pull and run `status`, preview, and `link` again. Content
updates take effect through existing links; new files need `link`. Keep
credentials, tokens, private keys, and machine-specific secrets out of Git;
[Secrets](#secrets) describes what enforces that.

To stop linking a file, unlink before removing or renaming it, while
homeskillet can still find it under `home/`:

```sh
homeskillet unlink --repo . --dry-run
homeskillet unlink --repo .
```

Then remove or rename the file and run `link` again. `unlink` removes only links
that point to files under `home/` in this clone. It does not remove source files
or parent directories, or restore your backups. Unlink before moving or deleting
the clone, then relink from its new location.

Every file is checked before anything changes, so a conflict or missing source
prevents every change. Operations are not transactional: an I/O failure partway
through can leave a partial installation. Resolve the error and rerun the
command, which is idempotent. Do not change files under `home/` while the
manager is running.

## Secrets

This repository is public, so three layers keep secrets and personal details
out of it:

1. [.gitignore](.gitignore) ignores credential, key, history, and environment
   files anywhere in the repository, including under `home/`: files named
   `credentials` or `credentials.*`, keys and keystores, everything in `.ssh`
   except `config` and public keys, and tool files such as `.netrc`, `.npmrc`,
   `.pgpass`, and kubeconfig.
2. The pre-commit hook, [.githooks/pre-commit](.githooks/pre-commit), runs
   [scripts/check-secrets.sh](scripts/check-secrets.sh) on what each commit
   would add. It blocks files that `.gitignore` ignores but were added with
   `git add -f`; private keys and AWS, GitHub, GitLab, Slack, Google, Stripe,
   npm, PyPI, and Anthropic tokens; and your home directory path and Git email.
   Findings name the file and line without printing the secret. The same hook
   runs `bash -n` and, when it is installed, ShellCheck on staged shell files
   (by extension, Bash startup file name, shebang, or `# shellcheck shell=`
   directive). It checks the staged content, not the working tree, runs every
   check, and blocks the commit if any of them fails.
3. GitHub Actions runs the same scan over every tracked file, so a commit made
   without the hook, or with `git commit --no-verify`, still fails.

For a deliberate, secret-free copy of an ignored file, such as an `.npmrc` with
only registry settings, add an exception like `!home/.npmrc` to `.gitignore`;
its contents are still scanned. For a reviewed false positive, add a
`secret-scan: allow` comment on that line. Run `bash scripts/check-secrets.sh
--all` to check every tracked file by hand. On GitHub, also turn on secret
scanning and push protection under Settings, Code security, so pushes with
known token formats are rejected on the server.

## Shell Snippets

`.bashrc` sources every file in `~/.bashrc.d` in alphabetical order, and login
shells reach it through `.bash_profile`. Environment defaults apply whether or
not a tool is installed; tool commands run only when the tool is on PATH, and
aliases, functions, completions, and the prompt load only in interactive shells.

| Snippet | Always applied | Interactive shells |
| --- | --- | --- |
| [aliases.sh](home/.bashrc.d/aliases.sh) | — | aliases: `l`, `la`, `hist`, `sudo`, `githash`, `tmuxa`, `tree`, `vi` for vim, and directory shortcuts (`..` to `.....`, `cd1` to `cd9`) |
| [aws.sh](home/.bashrc.d/aws.sh) | `AWS_REGION` and `AWS_DEFAULT_REGION` default to `us-west-2` (Oregon) | `aws` completion |
| [dotnet.sh](home/.bashrc.d/dotnet.sh) | .NET telemetry and first-run banner off; `~/.dotnet` and its global tools added to PATH when present | `dotnet` completion |
| [functions.sh](home/.bashrc.d/functions.sh) | — | shell: `hgrep`, `paths`, `timer`; network: `allips`, `localip`, `publicip`, `sshfingerprint`; text: `urlencode`; terminal: `colors`, `truecolor` |
| [gcp.sh](home/.bashrc.d/gcp.sh) | gcloud surveys and usage reporting off; `~/google-cloud-sdk/bin` added to PATH when present | `gcloud` completion for that install |
| [golang.sh](home/.bashrc.d/golang.sh) | `GOBIN`, or the first `GOPATH` entry's `bin`, added to PATH; Go telemetry off | — |
| [history.sh](home/.bashrc.d/history.sh) | 50,000 commands with timestamps, no duplicates, appended to `~/.bash_history` as each command runs | — |
| [kubectl.sh](home/.bashrc.d/kubectl.sh) | — | `kubectl` completion |
| [oh-my-posh.sh](home/.bashrc.d/oh-my-posh.sh) | — | prompt with the theme named by `OHMYPOSH_THEME` (`bubblesextra` by default): the date and time on the left with a 12-hour clock (`Sun Oct 25 03:51:28 AM PDT 2026`), and the path, Git, language versions, and battery on the right, on a line of their own when the terminal is too narrow for both |
| [opentofu.sh](home/.bashrc.d/opentofu.sh) | — | `tofu` completion |
| [python.sh](home/.bashrc.d/python.sh) | — | `uv` and `uvx` completion |
| [terraform.sh](home/.bashrc.d/terraform.sh) | `CHECKPOINT_DISABLE=1`, so no checkpoint calls to HashiCorp | `terraform` completion |
| [vscode.sh](home/.bashrc.d/vscode.sh) | — | `code_extensions_install` installs the listed extensions that are missing |

`.bashrc` also sets `DO_NOT_TRACK=1`, a telemetry opt-out some tools honor. Go
has no environment switch for telemetry, so `golang.sh` runs `go telemetry off`
once and Go keeps that setting. VS Code's telemetry is a setting instead:
`"telemetry.telemetryLevel": "off"` in its `settings.json`. OpenTofu also reads
the `TF_*` variables set in `terraform.sh`.

Most snippets also list optional defaults as commented exports. Uncomment one
to use it:

```sh
export CLOUDSDK_CORE_PROJECT=${CLOUDSDK_CORE_PROJECT:-example-project}
```

Defaults use the `${VAR:-value}` form, so a value already set by CI, direnv, or
another file wins and load order rarely matters. The exception is `golang.sh`,
which reads `GOBIN` and `GOPATH` as it runs: set those in `golang.sh` or with
`go env -w`, not in a file that sorts after it. Prefix a snippet's name with
`00-` or `zz-` to run it first or last.

History settings are assigned directly, because Bash and `/etc/profile` set
them before any snippet runs. Start a command with a space to keep it out of
history; override the sizes or filters in a later file such as `local.sh`.

Installers that offer to edit `.bashrc`, such as gcloud's `install.sh` and the
uv installer, would write through the link into this repository. Decline, or set
`UV_NO_MODIFY_PATH=1` for uv; the snippets already handle PATH and completion.
Credentials, kubeconfig files, and settings written by `aws configure` or
`gcloud config set` stay in their usual home-directory locations, unmanaged.

## Completion

Tab completion comes from the bash-completion package (`sudo dnf install
bash-completion` or `sudo apt install bash-completion`). Fedora's `/etc/bashrc`
loads it; Debian and Ubuntu leave that to the user's `.bashrc`, so this
`.bashrc` loads it when it is not loaded yet, in interactive shells, before the
snippets. Either way it loads once, and the snippets and `local.sh` can rely on
it. It loads each command's completion the first time you press Tab after that
command, so installed completions cost nothing at startup.

Completions come from:

- **Files named after a command** in `~/.local/share/bash-completion/completions`
  (`mytool` or `mytool.bash`), which take precedence over the system's. Files
  you add there yourself stay on that machine; files under
  `home/.local/share/bash-completion/completions/` in this repository are
  linked by homeskillet and shared. [homeskillet.bash](home/.local/share/bash-completion/completions/homeskillet.bash)
  is one: it completes homeskillet's commands, `self` subcommands, installed
  versions, options, and directories for `-repo`, `-home`, `-data-dir`, and
  `-prefix`.
- **The snippets**, which register their tools' completions (see the table
  above) when the tool is installed. A generated completion script runs only
  when the tool produced it successfully.
- **A `complete` line** next to a function or alias you define in a snippet or
  `local.sh`, such as `complete -A hostname sshfingerprint`.

A completion file sets `COMPREPLY` from the words on the command line and
registers itself with `complete`. For example, to complete a `deploy` command's
environments, then file names:

```bash
# ~/.local/share/bash-completion/completions/deploy.bash
# Completes deploy's first argument with an environment, then file names.
_deploy() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=()
    if ((COMP_CWORD == 1)); then
        mapfile -t COMPREPLY < <(compgen -W 'dev staging prod' -- "$cur")
    fi
}
complete -o default -F _deploy deploy
```

Write completions in plain Bash, as above. bash-completion 2.12 renamed its
helper functions (`_init_completion` became `_comp_initialize`) and keeps the
old names only in a compatibility file, so a completion built on either set
works on some distributions and not others. `compgen -W` expands its word list,
so pass it only fixed words or values you have checked, never raw command
output. The checks require every file in the repository's completions directory
to register a completion for the command it is named after.

## Git, Editors, and Login

[home/.config/git/config](home/.config/git/config) holds shared Git defaults:
`main` as the initial branch, rebasing pulls, automatic upstreams on first push,
pruned fetches, histogram diffs, `zdiff3` conflicts, reused conflict
resolutions, and aliases such as `git ghist` and `git unstage`. It needs Git
2.37 or later. Git reads it before `~/.gitconfig`, which wins, so keep your
name, email, signing key, and credential helpers in `~/.gitconfig`.

`~/.gitconfig` is never linked, because what it holds is personal and tools
such as `gh auth setup-git` add to it. The `gitconfig` setup step creates a
starter one instead, with commented examples for identity and SSH commit
signing and no settings, and never touches an existing file. The file must
exist: `git config --global` writes to `~/.gitconfig` only when it does, and
otherwise to the linked `~/.config/git/config`, which puts the change in this
repository. Set your identity after the step runs:

```sh
git config --global user.name 'Your Name'
git config --global user.email you@example.com
```

[home/.config/tmux/tmux.conf](home/.config/tmux/tmux.conf) needs tmux 3.2 or
later. It moves the prefix to `C-a`, starts windows and panes at 1, keeps
100,000 lines of scrollback, passes true color through, binds `C-a r` to
reload, and sets the terminal's title to
`tmux: session:window:name - pane title`, so the window or tab shows that tmux
is running. It uses `tmux-256color` where that terminfo entry exists and
`screen-256color` elsewhere, and waits 10 ms after Esc so key sequences arrive
whole without a noticeable delay in vim.

A window's tab in the tmux status bar turns red while any of its panes runs
`sudo`, `sudoedit`, `su`, `doas`, or `run0`, and every tab is red when tmux
itself runs as root. Ptyxis turns its header bar red for the same reason, but
inside tmux it sees only tmux, so the tab is the signal there. tmux knows only
the name of the program in front: `sudo` keeps the terminal for a whole
session when it uses its own pty (the default since sudo 1.9.14), so `sudo -i`
and `sudo su -` stay red until they exit, while a plain `su -` hands the
terminal to root's shell, which looks like any other shell. Use `su --pty -` or
`sudo -i` to keep the tab red.

[home/.vimrc](home/.vimrc) works on a stock vim without plugins. It loads Vim's
`defaults.vim` first (a vimrc otherwise skips it) and follows a project's
`.editorconfig` through Vim's bundled plugin. On top of that: marker folding,
two-space indents with spaces, persistent undo in a private `~/.vim/undo`, a
red ruler at column 120 (`colorcolumn`), trailing whitespace and non-ASCII
characters highlighted in every window, trailing whitespace stripped on save
(except in binary files, Markdown, and diffs), and `,` as the leader key. A
project whose `.editorconfig` sets `max_line_length` gets a second ruler just
past that limit.

[home/.curlrc](home/.curlrc) shows a single progress bar instead of curl's
statistics table. curl reads it on every run, scripts included, so keep it to
display preferences; the helpers pass `--disable` so it never affects them.

[home/.hushlogin](home/.hushlogin) turns off the last-login and
message-of-the-day banners that `login` and `sshd` print at the start of a
session; only its presence matters.

[home/.bash_logout](home/.bash_logout) runs when a login shell exits: a console
or SSH session, or `bash -l`, but not a desktop terminal window. On a Linux
virtual console (`/dev/tty1` and up) it clears the screen as the outermost
shell logs out, so the next person at the keyboard cannot read the session;
`clear_console`, where installed (Debian and Ubuntu), also erases the
scrollback. SSH sessions and terminal windows keep their screen. Then it runs
`~/.bash_logout.local`, an unmanaged file for machine-specific logout tasks,
when that exists.

At each login, including the graphical one (GNOME starts its session through a
login shell), `.bash_profile` configures Ptyxis and GNOME Terminal with
`gsettings`. It needs `gsettings` and a user D-Bus session, skips terminals that
are not installed, and writes only settings that differ. A change made in a
terminal's preferences is restored at the next login, so change these settings
in `.bash_profile` instead:

- **Font:** the Nerd Font named by `TERMINAL_FONT` (`MesloLGL Nerd Font 10`),
  so the prompt's glyphs render; the `meslo-nerd-font` setup step installs it.
- **Copy and paste:** Ctrl+C and Ctrl+V, as in other applications, replacing
  Ctrl+Shift+C and Ctrl+Shift+V. In Ptyxis, Ctrl+C copies only while text is
  selected; with nothing selected it interrupts the running program as usual,
  so click once to clear a selection before interrupting. GNOME Terminal
  consumes its copy shortcut even with nothing selected, which would leave no
  key to interrupt a program, so it keeps Ctrl+Shift+C for copy and gets only
  Ctrl+V for paste.
- **What Ctrl+V gives up:** while the clipboard holds text, programs no longer
  receive Ctrl+V. In Vim, start a block selection with Ctrl+Q instead.

## Customize

Keep personal and machine-specific settings out of this repository, in places
homeskillet never manages:

| To change | Where |
| --- | --- |
| Environment, aliases, functions for one machine | `~/.bashrc.d/local.sh`, created by you; it loads in alphabetical order with the snippets, so its assignments override defaults set before it, and `${VAR:-value}` defaults set after it yield to it |
| Git name, email, signing key, credential helpers | `~/.gitconfig`, created by the `gitconfig` setup step and then yours: `git config --global` writes there |
| Logout tasks for one machine | `~/.bash_logout.local`, created by you; `.bash_logout` runs it last |
| Prompt theme | `OHMYPOSH_THEME` in `local.sh`, which loads before `oh-my-posh.sh`: a theme's name from `~/.config/oh-my-posh/themes`, such as `bubbles`, or a path to any theme file; every bundled theme except `jandedobbeleer` starts with the date and time at the left |
| Tab completion for a command | a file named after it in `~/.local/share/bash-completion/completions` for one machine, or under `home/.local/share/bash-completion/completions/` to share it (see [Completion](#completion)) |
| Go's `GOBIN`, `GOPATH`, or other settings | `go env -w`, which Go saves outside this repository |

Shared settings belong in the repository files themselves: the clock format is
the `time_format` of the theme's `time` segment (a Go time layout), the terminal
font (`TERMINAL_FONT`) and copy and paste shortcuts are in `.bash_profile`, and
the editors and tools read the
files under `home/` described above. Edits there are shared by every machine
that links this clone, so commit them deliberately.

## Troubleshooting

- **`link` reports `conflict`:** a real file or another link is in the way.
  Move it to a backup directory, as shown under [Install](#install), and rerun
  `link`.
- **The prompt shows boxes or question marks:** the terminal font is not a Nerd
  Font. Run the `meslo-nerd-font` setup step, then log in again or pick
  `MesloLGL Nerd Font` in the terminal's preferences.
- **Ctrl+C or Ctrl+V still needs Shift:** GNOME Terminal keeps Ctrl+Shift+C
  for copy by design; otherwise the settings apply at login. Log out and back
  in, or run `bash -l -c exit` once; then
  `gsettings get org.gnome.Ptyxis.Shortcuts copy-clipboard` prints `'<ctrl>c'`.
- **Ctrl+C copies instead of interrupting:** text is selected. Click once to
  clear the selection, then press Ctrl+C again.
- **Tab completes only file names:** bash-completion is not installed or not
  loaded. Install it, open a new terminal, and check that
  `echo "${BASH_COMPLETION_VERSINFO[*]}"` prints a version.
- **A completion file does not load:** its name must match the command
  (`mytool` or `mytool.bash`), and it loads once per shell, so after editing it
  run `complete -r mytool` or open a new terminal. Check it with `bash -n` and
  `shellcheck`; older bash-completion versions hide its errors.
- **No prompt theme:** check `oh-my-posh version`, and that `OHMYPOSH_THEME`
  names a theme that exists in `~/.config/oh-my-posh/themes`.
- **A commit is blocked:** the hook prints each problem as `file:line: reason`,
  without the secret. Remove the secret, or for a reviewed false positive add a
  `secret-scan: allow` comment or a `!path` exception to `.gitignore`.
  `git commit --no-verify` skips the hook, but CI still runs the scan.
- **A new shell starts slowly:** time it with `time bash -i -c exit`, and find
  the slow snippet with `bash -x -i -c exit 2>&1 | less`. Completion generators
  and `go env` run once per shell.
- **An edit to a linked file disappears:** an editor that still has the old
  version open can save it over the change. Reload the file from disk before
  saving.
- **`git config --global` changed this repository:** `~/.gitconfig` did not
  exist, so Git wrote to the linked `~/.config/git/config`. Run the `gitconfig`
  setup step (or `init-gitconfig.sh`), move the new lines into `~/.gitconfig`,
  and restore the repository file with `git restore home/.config/git/config`.
- **`homeskillet link` reports a conflict for `.bash_logout`:** your
  distribution created a default one. It is usually empty apart from comments;
  check it, then link with `--force`, which moves it to a backup.
- **Colors look wrong in tmux:** `tmux show -gv default-terminal` should print
  `tmux-256color`; if it prints `screen-256color`, this system lacks that
  terminfo entry, which the fallback handles.

## Requirements

Bash and a GNU/Linux userland. Tools (Go, .NET, the cloud and infrastructure
CLIs, uv, Oh My Posh, tmux, vim, VS Code) and terminal applications are
optional and installed separately or through the setup steps; anything missing
is skipped.

## Checks

```sh
bash tests/check.sh
shellcheck home/.bashrc home/.bash_profile home/.bash_logout home/.bashrc.d/*.sh home/.local/share/helpers/sh/*.sh home/.local/share/bash-completion/completions/* scripts/*.sh tests/check.sh .githooks/pre-commit
```

`tests/check.sh` runs each startup file with Bash in an empty environment and a
temporary home directory, so it never reads or changes your real home; its
throwaway Git repositories ignore your global and system Git config, so commit
signing or hooks set there never prompt. It needs neither Go nor homeskillet.
It covers PATH handling, the AWS, Go, .NET, history, and telemetry defaults,
the terminal font and copy and paste settings (including missing terminals and
logins that need no changes), when `.bash_logout` clears the screen, every
completion file and the homeskillet completion's candidates, the helper
functions, the secret scan (with throwaway repositories and fake secrets), the
pre-commit hook, the install scripts (with a stub `curl`, so nothing is
downloaded), that the starter `~/.gitconfig` sets nothing, receives
`git config --global`, and never replaces a file, and that every snippet stays
silent when its tool is missing. When bash-completion is installed, it also checks
that `.bashrc` loads it and that it loads a completion from the user directory
on first use. When vim and tmux are installed, it loads `.vimrc` and
`tmux.conf`, fails on any error, and checks vim's ruler, tmux's terminal title,
and the red tab of a window running `sudo` or `su` (stand-ins named after them,
so nothing runs as root). When Oh My Posh is installed, it renders every theme
except `jandedobbeleer` and requires the date and time at the start of its top
line; otherwise those checks are reported as skipped. It stops at the
first failure and exits 0 when every check passes, 1 when a check fails, and 2
on a usage error.

ShellCheck needs no options, so it also works on a single file and in editor
integrations. Sourced files have no shebang, so each one starts with a
`# shellcheck shell=bash` directive; the lines that source files outside this
repository (`/etc/bashrc`, `~/.bashrc`, the `~/.bashrc.d` loop, and gcloud's
completion script) are marked `# shellcheck source=/dev/null`. No other warnings
are suppressed. GitHub Actions runs both commands on every push and pull
request.

[.pre-commit-config.yaml](.pre-commit-config.yaml) adds optional checks for
[pre-commit](https://pre-commit.com): YAML and JSON syntax, merge conflict
markers, file name case conflicts, line endings, final newlines, trailing
whitespace (Markdown line breaks and the themes' upstream formatting excepted),
shebangs and executable bits, private keys, AWS credentials, and ShellCheck. Run
them with `pre-commit run --all-files`; `pre-commit install` refuses to run
because `core.hooksPath` points Git at `.githooks`. The ShellCheck hook needs
Docker; without it, use `SKIP=shellcheck`.

To also link, check, and unlink every file under `home/` in a temporary home,
and dry-run the setup steps, pass a built manager:

```sh
bash tests/check.sh /path/to/homeskillet
```

For a manual sandbox, point the manager at an empty directory:

```sh
test_home=$(mktemp -d)
homeskillet link --repo . --home "$test_home"
homeskillet status --repo . --home "$test_home"
homeskillet unlink --repo . --home "$test_home"
```

## Contributing

[AGENTS.md](AGENTS.md) lists the conventions for changes: scope, snippet and
script structure, documentation, and the checks to run before finishing.
[.editorconfig](.editorconfig) sets matching indentation and line endings in
editors that support it. [CODEOWNERS](CODEOWNERS) requests the owner's review on
pull requests.

## License and Credits

Released under the [MIT License](LICENSE). The prompt themes in
[home/.config/oh-my-posh/themes/](home/.config/oh-my-posh/themes/) come from
[Oh My Posh](https://github.com/JanDeDobbeleer/oh-my-posh), also released under
the MIT License. Every theme except `jandedobbeleer` starts its top line with
the date and time on a 12-hour clock (`Sun Oct 25 03:51:28 AM PDT 2026`):
`bubbles` and `bubblesextra` add it at the left and move the right side of that
line to a line of its own when both do not fit (`"overflow": "break"`), and
`emodipt` shows the full date in its bracketed clock instead of only the time.
`jandedobbeleer`, which keeps its clock on the right, is the upstream file
unchanged.
