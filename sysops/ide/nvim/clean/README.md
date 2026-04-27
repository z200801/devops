# Neovim DevOps Config

Minimal DevOps-focused Neovim configuration based on `lazy.nvim`.

## Requirements

- Neovim >= 0.11
- git
- universal-ctags (`sudo apt install universal-ctags`)
- wl-clipboard (`sudo apt install wl-clipboard`)
- Node.js (for LSP servers)
- pip
- jsonlint (`npm install -g jsonlint`)
- yamllint (`pip install yamllint`)
- shellcheck (`sudo apt install shellcheck`)

## Installation

```bash
make backup
bash setup-nvim.sh
```

## Rollback

```bash
make restore
```

## Makefile targets

| Target | Description |
|--------|-------------|
| `make backup` | Backup current config and data |
| `make restore` | Restore latest backup |
| `make list` | List all backups |
| `make remove-backup BACKUP=<date>` | Remove specific backup |
| `make install` | Backup and install new config |
| `make update` | Update all plugins |
| `make mason-update` | Update all mason packages |
| `make du` | Show disk usage |
| `make clean-disabled` | Remove disabled config |

---

## Keybindings

> `Space` = `<leader>`

### Window Navigation

| Key | Action |
|-----|--------|
| `Ctrl+h` | Move to left window |
| `Ctrl+j` | Move to bottom window |
| `Ctrl+k` | Move to top window |
| `Ctrl+l` | Move to right window |

### Window Management

| Key | Action |
|-----|--------|
| `\` | Split horizontal |
| `\|` | Split vertical |
| `Space+h` | Terminal below |

### Buffers

| Key | Action |
|-----|--------|
| `Tab` | Next buffer |
| `Shift+Tab` | Previous buffer |
| `Space+bd` | Delete buffer |

### File Manager

| Key | Action |
|-----|--------|
| `Space+e` | Open Oil (file manager) |
| `Space+E` | Toggle Neo-tree (sidebar) |
| `F7` | Toggle Aerial (LSP symbol outline) |
| `F8` | Toggle Tagbar (ctags symbol outline) |

### Terminal

| Key | Action |
|-----|--------|
| `` ` `` | Toggle terminal (horizontal) |
| `Space+tv` | Terminal vertical |
| `Space+th` | Terminal horizontal |

### Git

| Key | Action |
|-----|--------|
| `Space+gg` | LazyGit |
| `Space+gp` | Preview hunk |
| `Space+gb` | Blame line |
| `Space+gd` | Diffview open |
| `Space+gh` | File history |

### LSP

| Key | Action |
|-----|--------|
| `Space+lf` | Format file |
| `Space+la` | Code action |
| `Space+lr` | Rename symbol |
| `Space+ld` | Show diagnostics |
| `gd` | Go to definition |
| `K` | Hover info |

### Search (Telescope)

| Key | Action |
|-----|--------|
| `Space+ff` | Find files |
| `Space+fg` | Live grep |
| `Space+fb` | Buffers |
| `Space+fo` | Recent files |
| `Space+f/` | Search in current buffer |
| `Space+fk` | Keymaps |
| `Space+fm` | Marks |

### DevOps (Telescope)

| Key | Action |
|-----|--------|
| `Space+fs` | Document symbols (LSP) |
| `Space+fr` | References (LSP) |
| `Space+fd` | Diagnostics (LSP) |
| `Space+fc` | Git commits |
| `Space+fB` | Git branches |
| `Space+fS` | Git status |
| `Space+fT` | Git stash |
| `Space+fp` | Projects |

### System (Telescope)

| Key | Action |
|-----|--------|
| `Space+fM` | Man pages |
| `Space+fe` | Environment variables |
| `Space+fh` | Help tags |
| `Space+md` | Toggle markdown render |
| `Space+?` | Cheatsheet |

---

## Plugins

| Plugin | Purpose |
|--------|---------|
| `lazy.nvim` | Plugin manager |
| `catppuccin` | Color scheme |
| `lualine` | Status line |
| `nvim-treesitter` | Syntax highlighting |
| `mason` + `nvim-lspconfig` | LSP servers |
| `nvim-cmp` | Autocompletion |
| `conform.nvim` | Formatting |
| `nvim-lint` | Linting |
| `gitsigns` | Git integration in buffer |
| `lazygit.nvim` | LazyGit interface |
| `diffview.nvim` | Git diff and history |
| `oil.nvim` | File manager (buffer style) |
| `neo-tree.nvim` | File manager (sidebar) |
| `telescope.nvim` | Fuzzy finder |
| `telescope-fzf-native` | Fast fuzzy search |
| `aerial.nvim` | Symbol outline (LSP) |
| `tagbar` | Symbol outline (ctags) |
| `toggleterm.nvim` | Terminal management |
| `which-key.nvim` | Keybinding hints |
| `indent-blankline` | Indent guides |
| `render-markdown.nvim` | Markdown rendering |

## LSP Servers

| Language | Server |
|----------|--------|
| Python | `pyright` |
| Bash/sh | `bashls` |
| Lua | `lua_ls` |
| YAML | `yamlls` |
| Dockerfile | `dockerls` |
| Ansible | `ansiblels` |

## YAML Schemas

| Schema | Pattern |
|--------|---------|
| docker-compose | `docker-compose*.yaml`, `docker-compose*.yml` |
| Docker Swarm stack | `stack*.yaml`, `stack*.yml` |

## Formatters

| Language | Formatter |
|----------|-----------|
| Python | `black`, `isort` |
| Bash/sh | `shfmt` |
| Lua | `stylua` |
| JSON | `prettier` |
| YAML | `prettier` |

## Linters

| Language | Linter |
|----------|--------|
| Python | `flake8` |
| Bash/sh | `shellcheck` |
| YAML | `yamllint` |
| JSON | `jsonlint` |
