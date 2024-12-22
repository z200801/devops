#!/bin/bash

# Url's
# https://docs.astronvim.com/
# https://habr.com/ru/companies/billing/articles/786512/

function _install_dependencies_app(){
 # Install need programs
 python_venv="python3.$(python3 -V|cut -d ' ' -f2| cut -d '.' -f2)-venv"
 sudo apt install -y librust-tree-sitter-config-dev ripgrep gdu nodejs "${python_venv}" npm

 npm install tree-sitter-cli

 # Install lazygit
 LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
 curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
 tar xf lazygit.tar.gz lazygit
 sudo install lazygit /usr/local/bin
 rm lazygit*

 # Install bottom
 BOTTON_LAST_TAG=$(curl -s "https://github.com/ClementTsang/bottom/releases"|grep -m 1 -Po "\/releases\/tag\/\K[^(nigthly)](?:[\d\.]+)") #"
 curl -LO https://github.com/ClementTsang/bottom/releases/download/"${BOTTON_LAST_TAG}"/bottom_"${BOTTON_LAST_TAG}"_amd64.deb
 sudo dpkg -i bottom_"${BOTTON_LAST_TAG}"_amd64.deb
 rm bottom_"${BOTTON_LAST_TAG}"_amd64.deb
}

function _bu_old_config(){
 # Backup old
 mv ~/.config/nvim ~/.config/nvim.bak
 mv ~/.local/share/nvim ~/.local/share/nvim.bak
 mv ~/.local/state/nvim ~/.local/state/nvim.bak
 mv ~/.cache/nvim ~/.cache/nvim.bak
}

function _clone_repo(){
 # Clone
 git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim
}

####
_install_dependencies_app
_bu_old_config
_clone_repo

exit 0

After instal astrovim
in cli
LspInstall bashls pylsp pyright awk_ls
LspInstall ansiblels docker_compose_language_service dockerls
LspInstall terraformls tflint
LspInstall ansible
LspInstall ansible-lint gitleaks htmlhint jsonlint
LspInstall markdownlint markdownlint-cli2 pylint pyre shellcheck shellharden tfsec textlint yamllint mypy pyflakes
TSInstall terraform  
DapInstall python bash


Lazy check
Lazy update
Lazy clean


