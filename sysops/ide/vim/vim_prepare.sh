#!/bin/bash
#
# Prepare vim for simple use 
# Author: z200801@gmail.com
#
# Use plugins:
#   NERDTree
#   AirLine
#   Commentary
#   TagBar
#   Universal-ctags
#   ctags-exuberant
# 

function _install_vim() {
 _ver=$(vim --version|head -n 1|awk '{print $5}'|cut -d '.' -f1)
 if [ ${_ver} -ge 9 ]; then return 0; fi
 sudo add-apt-repository ppa:jonathonf/vim
 sudo apt update && sudo apt install -y vim
}

function _color_scheme(){
 _dir_cs="${HOME}/.vim/colors"
 if [ ! -d "${_dir_cs}" ]; then mkdir -p "${_dir_cs}"; fi
 wget https://raw.githubusercontent.com/morhetz/gruvbox/master/colors/gruvbox.vim -O ~/.vim/colors/gruvbox.vim
 _cs_="colorscheme desert\ncolorscheme gruvbox\nsyntax on colorscheme gruvbox"
    grep -q "colorscheme" ~/.vimrc || echo -e "${_cs_}">>~/.vimrc
}
#### Main
#
_install_vim
_color_scheme

### Plugins
# NERDTree
git clone https://github.com/preservim/nerdtree.git ~/.vim/pack/vendor/start/nerdtree
vim -u NONE -c "helptags ~/.vim/pack/vendor/start/nerdtree/doc" -c q

# AirLine
git clone https://github.com/vim-airline/vim-airline ~/.vim/pack/dist/start/vim-airline
git clone https://github.com/vim-airline/vim-airline-themes ~/.vim/pack/dist/start/vim-airline-themes
vim -u NONE -c "helptags ~/.vim/pack/dist/start/vim-airline/doc" -c q
vim -u NONE -c "helptags ~/.vim/pack/dist/start/vim-airline-themes/doc" -c q

# Commentary
git clone https://github.com/tpope/vim-commentary.git ~/.vim/pack/dist/start/commentary
vim -u NONE -c "helptags ~/.vim/pack/dist/start/commentary/doc" -c

# TagBar
if ! which ctags 1>&2>/dev/null; then sudo apt install -y universal-ctags; fi
git clone https://github.com/preservim/tagbar ~/.vim/pack/dist/start/tagbar
vim -u NONE -c "helptags ~/.vim/pack/dist/start/tagbar/doc" -c q

if [ -e "${HOME}/.vimrc" ]; then mv ${HOME}/.vimrc ${HOME}.vimrc.old; fi
cat>>${HOME}/.vimrc<< EOF
syntax on
filetype plugin indent on 
set ai smartindent
set number relativenumber nocompatible
set omnifunc=syntaxcomplete#Complete
set mousemodel=popup
set mouse=a
set backspace=indent,eol,start
set completeopt-=preview
set completeopt-=preview
set ttyfast
set enc=utf-8
set termencoding=utf-8
set ls=2
set incsearch
set hlsearch
set cursorline

set nobackup
set nowritebackup
set noswapfile

set smarttab
set tabstop=8

colorscheme desert
colorscheme gruvbox
syntax on colorscheme gruvbox

" Set relative number Ctrl-l+Crtl-l
nmap <C-L><C-L> :set invrelativenumber<CR>

nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <Space>e :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>

set laststatus=2
let g:airline_theme='badwolf'
let g:airline_powerline_fonts = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'

set list listchars=tab:>-,nbsp:.,trail:.,extends:>,precedes:<,eol:↲
set showbreak=↪\
set nolist

" F8 TagBar
nmap <F8> :TagbarToggle<CR>
let g:tagbar_sort = 0


" split horizontal
noremap " :split<CR>

" split vertical
nmap \| :vsplit<CR>


" Commenting blocks of code.
" Space / - comment
" Space \ - uncomment
" augroup commenting_blocks_of_code
"   autocmd!
"   autocmd FileType c,cpp,java,scala let b:comment_leader = '// '
"   autocmd FileType sh,ruby,python   let b:comment_leader = '# '
"   autocmd FileType conf,fstab       let b:comment_leader = '# '
"   autocmd FileType tex              let b:comment_leader = '% '
"   autocmd FileType mail             let b:comment_leader = '> '
"   autocmd FileType vim              let b:comment_leader = '" '
" augroup END
" noremap <silent> <Space>/ :<C-B>silent <C-E>s/^/<C-R>=escape(b:comment_leader,'\/')<CR>/<CR>:nohlsearch<CR>
" noremap <silent> <Space>\ :<C-B>silent <C-E>s/^\V<C-R>=escape(b:comment_leader,'\/')<CR>//e<CR>:nohlsearch<CR>

" Coment/uncomment blocks
noremap <Space>/ :Commentary<CR>

" mouse resize window 
set ttymouse=xterm2

" Run horizontal window /bin/bash on <Space>th
nnoremap <silent><Space>th :belowright terminal /bin/bash<CR>
" Run vertical window /bin/bash on <Space>tv
nnoremap <silent><Space>tv :belowright vertical terminal /bin/bash<CR>
let g:copilot_enabled = 0
let g:codeium_enabled = v:false

if &term == "screen"
 set t_Co=256
endif
EOF
