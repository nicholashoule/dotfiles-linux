# shellcheck shell=bash
# Oh My Posh
# https://ohmyposh.dev/docs/configuration/concepts
# Themes: https://ohmyposh.dev/docs/themes
# Theme sources: https://github.com/JanDeDobbeleer/oh-my-posh/tree/main/themes
# Font: set the terminal to a Nerd Font (installed via: oh-my-posh font install meslo)
# OHMYPOSH_THEME picks the theme: the name of a theme in ~/.config/oh-my-posh/themes
# (without .omp.json; bubblesextra by default) or a path to any theme file. Set it
# in ~/.bashrc.d/local.sh, which loads earlier, or export it first.
# The generated prompt runs only if `oh-my-posh init` produced it successfully.
# Config auto-reload is a saved setting, turned on once by
# the install-oh-my-posh.sh helper (or `oh-my-posh enable reload`), not at each start.
if [[ $- == *i* ]] && command -v oh-my-posh >/dev/null; then
    OHMYPOSH_THEME=${OHMYPOSH_THEME:-bubblesextra}
    case $OHMYPOSH_THEME in
        */*) ;;
        *) OHMYPOSH_THEME="$HOME/.config/oh-my-posh/themes/$OHMYPOSH_THEME.omp.json" ;;
    esac
    if [[ -f $OHMYPOSH_THEME ]] && omp_init=$(oh-my-posh init bash --config "$OHMYPOSH_THEME"); then
        eval "$omp_init"
    fi
    unset omp_init
fi
