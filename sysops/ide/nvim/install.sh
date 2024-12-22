#!/bin/bash

_cfg_dir="${HOME}/.config/nvim"

#_cfg_dir="./"

if ! which nvim; then 
# sudo add-apt-repository ppa:neovim-ppa/unstable -y
# sudo apt install neovim
 sudo snap install nvim --classic
fi

if [ ! -d ${_cfg_dir} ]; then mkdir -p "${_cfg_dir}"; fi

cat >"${_cfg_dir}/init.vim"<<- EOF
:set mouse
:set number
:set relativenumber
:set smarttab
:set tabstop=2
:set shiftwidth=2
:set softtabstop=2
:set autoindent

call plug#begin()
Plug 'https://github.com/vim-airline/vim-airline'
Plug 'https://github.com/preservim/nerdtree'
Plug 'https://github.com/ryanoasis/vim-devicons'
call plug#end()

nnoremap <leader>n :NERDTreeFocus<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
nnoremap <C-f> :NERDTreeFind<CR>

EOF

sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
 https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

# In nvim install plugin -> :PluginInstall


