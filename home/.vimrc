" Vim settings for a stock vim, no plugin manager required.
" https://vimhelp.org/
" vim: foldmethod=marker

" GENERAL {{{
set encoding=utf-8
" A vimrc stops Vim from loading defaults.vim, so load it first, as `:help
" defaults.vim` recommends: incsearch, display=truncate, no octal for CTRL-A,
" syntax and filetype detection, and reopening files at the last position
" (except commit messages and diffs). The settings below build on it.
unlet! skip_defaults_vim
if filereadable(expand('$VIMRUNTIME/defaults.vim'))
  source $VIMRUNTIME/defaults.vim
endif
" Follow a project's .editorconfig (Vim 9.0.1799 and later bundle the plugin).
silent! packadd! editorconfig
" }}}

" FOLDING {{{
set foldenable
set foldlevelstart=0
set foldnestmax=10
set foldmethod=marker
" Space opens and closes folds
nnoremap <space> za
" }}}

" FUNCTIONS {{{
" Cycle relativenumber -> number -> none
function! s:ToggleNumber() abort
  if &relativenumber
    set norelativenumber number number?
  elseif &number
    set nonumber nonumber?
  else
    set relativenumber relativenumber?
  endif
endfunction

" Toggle paste mode (modern terminals use bracketed paste, so this is rarely needed)
function! s:TogglePaste() abort
  if &paste
    set nopaste nopaste?
  else
    set paste paste?
  endif
endfunction

" Run a command without moving the cursor or replacing the last search
function! s:Preserve(command) abort
  let l:search = @/
  let l:view = winsaveview()
  execute a:command
  let @/ = l:search
  call winrestview(l:view)
endfunction

" Highlight trailing whitespace (except just before the cursor while typing) and
" non-ASCII characters, once per window. `:match` would cover only the window
" that was current at startup, and syntax matches vanish when syntax reloads.
function! s:Highlights() abort
  if !exists('w:dotfiles_matches')
    let w:dotfiles_matches = [
          \ matchadd('ExtraWhitespace', '\s\+\%#\@<!$'),
          \ matchadd('NonAscii', '[^\x00-\x7F]')]
  endif
endfunction

" Colors for those highlights, reapplied after a colorscheme change
function! s:HighlightColors() abort
  highlight ExtraWhitespace ctermbg=darkblue guibg=darkblue
  highlight NonAscii ctermbg=1 guibg=Red term=standout
endfunction
" }}}

" AUTOCOMMANDS {{{
augroup dotfiles
  autocmd!
  " Strip trailing whitespace on save, keeping the cursor and last search; not in
  " binary files, Markdown (two trailing spaces are a line break), or diffs
  " (blank context lines)
  autocmd BufWritePre * if !&binary && index(['markdown', 'diff'], &filetype) < 0
        \ | call s:Preserve('%s/\s\+$//e') | endif
  autocmd VimEnter,WinNew,BufWinEnter * call s:Highlights()
  autocmd ColorScheme * call s:HighlightColors()
augroup END
call s:HighlightColors()
" }}}

" UI {{{
set showcmd
set laststatus=2 ruler
set wildmenu
if has('mouse')
  set mouse=a
endif
set cursorline
" A ruler at column 120, the line length to stay within (red in Vim's default
" colors, the ColorColumn group). A project's .editorconfig max_line_length adds
" its own ruler just past that limit.
if exists('+colorcolumn')
  set colorcolumn=120
endif
set showmatch
set completeopt=longest,menu
set backspace=indent,eol,start
" }}}

" INDENTATION {{{
" Two-space indents with spaces. tabstop stays at 8, so files that use real tabs
" (Makefiles, Git config) display as their authors intended; filetype indent
" rules do the language-specific work (smartindent would push # comments to
" column 0). A project's .editorconfig overrides these per file.
set autoindent
set expandtab
set shiftwidth=2
set softtabstop=2
set cpoptions+=J " two spaces after a period end a sentence
" }}}

" SEARCHING {{{
set hlsearch
set ignorecase
set smartcase
" }}}

" MAPPINGS & COMMANDS {{{
let mapleader = ","

" Beginning and end of line (replacing the B and E word motions)
nnoremap B ^
nnoremap E $
" Reselect the last inserted text
nnoremap gV `[v`]
" Clear search highlighting
nnoremap <silent> <leader><space> :nohlsearch<CR>
" Strip trailing whitespace now
nnoremap <silent> _$ :call <SID>Preserve('%s/\s\+$//e')<CR>
" Quote a word: ,q" ,q' ; remove quotes around a WORD: ,qd
nnoremap <Leader>q" ciw""<Esc>P
nnoremap <Leader>q' ciw''<Esc>P
nnoremap <Leader>qd daW"=substitute(@@,"'\\\|\"","","g")<CR>P
" Next and previous buffer. Terminals send CTRL-I as Tab, so this also replaces
" CTRL-I (jump forward); CTRL-O still jumps back.
nnoremap <silent> <Tab> :bnext<CR>
nnoremap <silent> <S-Tab> :bprevious<CR>
" Toggle line numbers and paste mode
nnoremap <silent> <Leader>n :call <SID>ToggleNumber()<CR>
nnoremap <silent> <Leader>tp :call <SID>TogglePaste()<CR>
" System clipboard: ,y ,p use the selection register, ,Y ,P the clipboard
noremap <Leader>y "*y
noremap <Leader>p "*p
noremap <Leader>Y "+y
noremap <Leader>P "+p
" Forgiving capitals
command! WQ wq
command! Wq wq
command! W w
command! Q q
" }}}

" FILES & HISTORY {{{
set autoread
set hidden
set history=10000
set timeout timeoutlen=1000 " wait for mapped key sequences
set ttimeout ttimeoutlen=50 " but not for terminal key codes, so Esc is instant
set noswapfile
set nobackup
set nowritebackup
" Persistent undo in a private directory (undo files hold file contents)
if has('persistent_undo')
  let s:undodir = expand('~/.vim/undo')
  if !isdirectory(s:undodir)
    call mkdir(s:undodir, 'p', 0700)
  endif
  let &undodir = s:undodir
  set undofile
endif
" }}}
