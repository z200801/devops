# Neovim DevOps Конфіг

Мінімальний конфіг для DevOps розробки на базі `lazy.nvim`.

## Вимоги

- Neovim >= 0.11
- git
- universal-ctags (`sudo apt install universal-ctags`)
- wl-clipboard (`sudo apt install wl-clipboard`)
- Node.js (для LSP серверів)
- pip
- jsonlint (`npm install -g jsonlint`)
- yamllint (`pip install yamllint`)
- shellcheck (`sudo apt install shellcheck`)

## Встановлення

```bash
make backup
bash setup-nvim.sh
```

## Відкат

```bash
make restore
```

## Makefile таргети

| Таргет | Опис |
|--------|------|
| `make backup` | Зберегти поточний конфіг і дані |
| `make restore` | Відновити останній backup |
| `make list` | Переглянути всі backup |
| `make remove-backup BACKUP=<date>` | Видалити конкретний backup |
| `make install` | Backup і встановити новий конфіг |
| `make update` | Оновити всі плагіни |
| `make mason-update` | Оновити всі mason пакети |
| `make du` | Показати використання диску |
| `make clean-disabled` | Видалити вимкнений конфіг |

---

## Гарячі клавіші

> `Space` = `<leader>`

### Навігація між вікнами

| Клавіша | Дія |
|---------|-----|
| `Ctrl+h` | Вікно ліворуч |
| `Ctrl+j` | Вікно вниз |
| `Ctrl+k` | Вікно вгору |
| `Ctrl+l` | Вікно праворуч |

### Вікна

| Клавіша | Дія |
|---------|-----|
| `\` | Розділити горизонтально |
| `\|` | Розділити вертикально |
| `Space+h` | Термінал внизу |

### Буфери

| Клавіша | Дія |
|---------|-----|
| `Tab` | Наступний буфер |
| `Shift+Tab` | Попередній буфер |
| `Space+bd` | Закрити буфер |

### Файловий менеджер

| Клавіша | Дія |
|---------|-----|
| `Space+e` | Відкрити Oil (файловий менеджер) |
| `Space+E` | Toggle Neo-tree (sidebar) |
| `F7` | Toggle Aerial (структура через LSP) |
| `F8` | Toggle Tagbar (структура через ctags) |

### Термінал

| Клавіша | Дія |
|---------|-----|
| `` ` `` | Toggle термінал (горизонтальний) |
| `Space+tv` | Термінал вертикальний |
| `Space+th` | Термінал горизонтальний |

### Git

| Клавіша | Дія |
|---------|-----|
| `Space+gg` | LazyGit |
| `Space+gp` | Preview hunk |
| `Space+gb` | Blame line |
| `Space+gd` | Diffview open |
| `Space+gh` | File history |

### LSP

| Клавіша | Дія |
|---------|-----|
| `Space+lf` | Форматувати файл |
| `Space+la` | Code action |
| `Space+lr` | Перейменувати |
| `Space+ld` | Показати діагностику |
| `gd` | Перейти до визначення |
| `K` | Hover (підказка) |

### Пошук (Telescope)

| Клавіша | Дія |
|---------|-----|
| `Space+ff` | Пошук файлів |
| `Space+fg` | Пошук по вмісту |
| `Space+fb` | Буфери |
| `Space+fo` | Нещодавні файли |
| `Space+f/` | Пошук в поточному буфері |
| `Space+fk` | Keymaps |
| `Space+fm` | Marks |

### DevOps (Telescope)

| Клавіша | Дія |
|---------|-----|
| `Space+fs` | Символи документу (LSP) |
| `Space+fr` | References (LSP) |
| `Space+fd` | Діагностика (LSP) |
| `Space+fc` | Git commits |
| `Space+fB` | Git branches |
| `Space+fS` | Git status |
| `Space+fT` | Git stash |
| `Space+fp` | Projects |

### System

| Клавіша | Дія |
|---------|-----|
| `Space+fM` | Man pages |
| `Space+fe` | Environment variables |
| `Space+fh` | Help tags |
| `Space+md` | Toggle markdown render |
| `Space+ca` | Toggle Codeium |
| `Space+?` | Cheatsheet |

### Codeium (режим вводу)

| Клавіша | Дія |
|---------|-----|
| `Ctrl+l` | Прийняти підказку |
| `Alt+]` | Наступна підказка |
| `Alt+[` | Попередня підказка |

---

## Плагіни

| Плагін | Призначення |
|--------|-------------|
| `lazy.nvim` | Менеджер плагінів |
| `catppuccin` | Кольорова схема |
| `lualine` | Статус рядок |
| `nvim-treesitter` | Підсвічування синтаксису |
| `mason` + `nvim-lspconfig` | LSP сервери |
| `nvim-cmp` | Автодоповнення |
| `conform.nvim` | Форматування |
| `nvim-lint` | Лінтери |
| `gitsigns` | Git інтеграція в буфері |
| `lazygit.nvim` | LazyGit інтерфейс |
| `diffview.nvim` | Git diff і history |
| `oil.nvim` | Файловий менеджер (буфер стиль) |
| `neo-tree.nvim` | Файловий менеджер (sidebar) |
| `telescope.nvim` | Fuzzy finder |
| `telescope-fzf-native` | Швидкий fuzzy пошук |
| `aerial.nvim` | Структура файлу (LSP) |
| `tagbar` | Структура файлу (ctags) |
| `toggleterm.nvim` | Управління терміналом |
| `which-key.nvim` | Підказки клавіш |
| `indent-blankline` | Відступи |
| `render-markdown.nvim` | Рендеринг markdown |
| `codeium.vim` | AI автодоповнення |

## LSP Сервери

| Мова | Сервер |
|------|--------|
| Python | `pyright` |
| Bash/sh | `bashls` |
| Lua | `lua_ls` |
| YAML | `yamlls` |
| Dockerfile | `dockerls` |
| Ansible | `ansiblels` |

## YAML Схеми

| Схема | Патерн |
|-------|--------|
| docker-compose | `docker-compose*.yaml`, `docker-compose*.yml` |
| Docker Swarm stack | `stack*.yaml`, `stack*.yml` |

## Форматери

| Мова | Форматер |
|------|----------|
| Python | `black`, `isort` |
| Bash/sh | `shfmt` |
| Lua | `stylua` |
| JSON | `prettier` |
| YAML | `prettier` |

## Лінтери

| Мова | Лінтер |
|------|--------|
| Python | `flake8` |
| Bash/sh | `shellcheck` |
| YAML | `yamllint` |
| JSON | `jsonlint` |
