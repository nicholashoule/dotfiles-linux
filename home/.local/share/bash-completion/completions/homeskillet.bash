# shellcheck shell=bash
# Bash completion for homeskillet, the manager that links these dotfiles.
# bash-completion loads a file from this directory the first time its command is
# completed in a shell; the file is named after the command, with or without .bash.
# Plain Bash without bash-completion's helper functions, so it works with any
# bash-completion version. Keep it in step with `homeskillet --help`.

# _homeskillet COMMAND completes the word at COMP_CWORD into COMPREPLY: commands,
# self subcommands, installed versions, options (with one dash or two, as Go's flag
# package accepts), and directories for the options that take a path. Positions
# that take a repository or file fall back to file names (complete -o default).
_homeskillet() {
    local cur prev word version rest i IFS=$' \t\n'
    local -a words opts candidates
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD - 1]-}
    words=()
    opts=()
    candidates=()
    COMPREPLY=()

    # COMP_WORDBREAKS splits -option=value into separate words at the =.
    if [[ $cur == = ]]; then
        cur=''
    elif [[ $prev == = ]]; then
        prev=${COMP_WORDS[COMP_CWORD - 2]-}
    fi

    case $prev in
        -data-dir | --data-dir | -home | --home | -prefix | --prefix | -repo | --repo)
            compopt -o filenames 2>/dev/null
            mapfile -t COMPREPLY < <(compgen -d -- "$cur")
            return
            ;;
        -platform | --platform)
            mapfile -t COMPREPLY < <(compgen -W 'linux darwin linux/amd64 linux/arm64 darwin/amd64 darwin/arm64' -- "$cur")
            return
            ;;
    esac

    # The words before the cursor that are neither options nor option values.
    for ((i = 1; i < COMP_CWORD; i++)); do
        word=${COMP_WORDS[i]}
        case $word in
            -data-dir | --data-dir | -home | --home | -platform | --platform | -prefix | --prefix | -repo | --repo)
                if [[ ${COMP_WORDS[i + 1]-} == = ]]; then
                    ((i += 1))
                fi
                ((i += 1))
                ;;
            -*) ;;
            *) words+=("$word") ;;
        esac
    done

    if [[ $cur == -* ]]; then
        opts=(-allow-root -data-dir -dry-run -home -platform -repo)
        case ${words[0]-} in
            '') opts+=(-force -prefix -yes) ;;
            link) opts+=(-force) ;;
            setup) opts+=(-yes) ;;
            self) opts+=(-prefix) ;;
            version) opts=() ;;
        esac
        if [[ $cur == --* ]]; then
            opts=("${opts[@]/#/-}")
        fi
        mapfile -t COMPREPLY < <(compgen -W "${opts[*]}" -- "$cur")
        return
    fi

    case ${words[0]-} in
        '')
            candidates=(status link unlink setup self version)
            ;;
        self | version)
            # These positions take no file names, even when nothing matches.
            compopt +o default 2>/dev/null
            if [[ ${words[0]} == self && ${#words[@]} -eq 1 ]]; then
                candidates=(install list use remove)
            elif [[ ${words[0]} == self && ${#words[@]} -eq 2 && (${words[1]} == use || ${words[1]} == remove) ]]; then
                if [[ ${words[1]} == use ]]; then
                    candidates=(latest previous)
                fi
                # The first column of `homeskillet self list` is the version. compgen
                # expands its word list, so only plain version strings are offered.
                while IFS=$'\t' read -r version rest; do
                    if [[ $version =~ ^[[:alnum:]._+-]+$ ]]; then
                        candidates+=("$version")
                    fi
                done < <("$1" self list 2>/dev/null)
            fi
            ;;
    esac
    mapfile -t COMPREPLY < <(compgen -W "${candidates[*]}" -- "$cur")
}
complete -o default -F _homeskillet homeskillet
