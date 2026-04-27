cat > setup-nvim.sh << 'SCRIPT'
#!/usr/bin/env bash
set -e

NVIM_CONFIG="$HOME/.config/nvim"
mkdir -p "$NVIM_CONFIG/lua/config"
mkdir -p "$NVIM_CONFIG/lua/plugins"

# init.lua
cat > "$NVIM_CONFIG/init.lua" << 'EOF'
require("config.options")
require("config.lazy")
require("config.keymaps")
EOF

# config/options.lua
cat > "$NVIM_CONFIG/lua/config/options.lua" << 'EOF'
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true
opt.wrap = false
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.splitright = true
opt.splitbelow = true
opt.scrolloff = 8
opt.clipboard = "unnamedplus"
EOF

# config/lazy.lua
cat > "$NVIM_CONFIG/lua/config/lazy.lua" << 'EOF'
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
  change_detection = { notify = false },
})
EOF

# config/keymaps.lua
cat > "$NVIM_CONFIG/lua/config/keymaps.lua" << 'EOF'
local map = vim.keymap.set

-- навігація між вікнами
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- файловий менеджер
map("n", "<leader>e", "<cmd>Oil<cr>", { desc = "File manager" })

-- git
map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>gp", "<cmd>Gitsigns preview_hunk<cr>", { desc = "Preview hunk" })
map("n", "<leader>gb", "<cmd>Gitsigns blame_line<cr>", { desc = "Blame line" })
map("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Diff view" })
map("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })

-- LSP
map("n", "<leader>lf", "<cmd>lua vim.lsp.buf.format()<cr>", { desc = "Format" })
map("n", "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>", { desc = "Code action" })
map("n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", { desc = "Go to definition" })
map("n", "K", "<cmd>lua vim.lsp.buf.hover()<cr>", { desc = "Hover" })
map("n", "<leader>lr", "<cmd>lua vim.lsp.buf.rename()<cr>", { desc = "Rename" })
map("n", "<leader>ld", "<cmd>lua vim.diagnostic.open_float()<cr>", { desc = "Diagnostics" })

-- буфери
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })
map("n", "<Tab>", "<cmd>bnext<cr>")
map("n", "<S-Tab>", "<cmd>bprev<cr>")

-- вікна
map("n", "\\", "<cmd>split<cr>", { desc = "Split horizontal" })
map("n", "|", "<cmd>vsplit<cr>", { desc = "Split vertical" })
map("n", "<leader>h", "<cmd>split | terminal<cr>", { desc = "Terminal below" })

-- пошук
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })
map("n", "<leader>fo", "<cmd>Telescope oldfiles<cr>", { desc = "Recent files" })
map("n", "<leader>f/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "Search in buffer" })
map("n", "<leader>fk", "<cmd>Telescope keymaps<cr>", { desc = "Keymaps" })
map("n", "<leader>fm", "<cmd>Telescope marks<cr>", { desc = "Marks" })

-- DevOps
map("n", "<leader>fs", "<cmd>Telescope lsp_document_symbols<cr>", { desc = "Document symbols" })
map("n", "<leader>fr", "<cmd>Telescope lsp_references<cr>", { desc = "References" })
map("n", "<leader>fd", "<cmd>Telescope diagnostics<cr>", { desc = "Diagnostics" })
map("n", "<leader>fc", "<cmd>Telescope git_commits<cr>", { desc = "Git commits" })
map("n", "<leader>fB", "<cmd>Telescope git_branches<cr>", { desc = "Git branches" })
map("n", "<leader>fS", "<cmd>Telescope git_status<cr>", { desc = "Git status" })
map("n", "<leader>fT", "<cmd>Telescope git_stash<cr>", { desc = "Git stash" })
map("n", "<leader>fp", "<cmd>Telescope projects<cr>", { desc = "Projects" })

-- System
map("n", "<leader>fM", "<cmd>Telescope man_pages<cr>", { desc = "Man pages" })
map("n", "<leader>fe", "<cmd>Telescope env<cr>", { desc = "Environment variables" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help tags" })
map("n", "<leader>md", "<cmd>RenderMarkdown toggle<cr>", { desc = "Toggle markdown render" })

EOF

# plugins/ui.lua
cat > "$NVIM_CONFIG/lua/plugins/ui.lua" << 'EOF'
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      vim.cmd("colorscheme catppuccin-mocha")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { theme = "catppuccin" },
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {},
  },
}
EOF

# plugins/treesitter.lua
cat > "$NVIM_CONFIG/lua/plugins/treesitter.lua" << 'EOF'
return {
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter").setup({
        ensure_installed = { "lua", "python", "bash", "json", "yaml", "toml", "markdown" },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end,
  },
}
EOF

# plugins/lsp.lua
cat > "$NVIM_CONFIG/lua/plugins/lsp.lua" << 'EOF'
return {
  {
    "williamboman/mason.nvim",
    opts = {},
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "pyright", "bashls", "lua_ls", "yamlls", "dockerls", "ansiblels" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      vim.lsp.config("pyright", {})
      vim.lsp.config("bashls", {})
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      })
      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            schemas = {
              ["https://raw.githubusercontent.com/compose-spec/compose-spec/master/schema/compose-spec.json"] = "docker-compose*.yaml","docker-compose*.yml",
              ["https://raw.githubusercontent.com/docker/compose/master/schema/compose-spec.json"] = "stack*.yaml","stack*.yml",
            },
          },
        },
      })
      vim.lsp.config("dockerls", {})
      vim.lsp.config("ansiblels", {})
      vim.schedule(function()
        vim.lsp.enable({ "pyright", "bashls", "lua_ls", "yamlls", "dockerls", "ansiblels" })
      end)
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      cmp.setup({
        snippet = {
          expand = function(args) require("luasnip").lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping.select_next_item(),
          ["<S-Tab>"] = cmp.mapping.select_prev_item(),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },
}
EOF

# plugins/format.lua
cat > "$NVIM_CONFIG/lua/plugins/format.lua" << 'EOF'
return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = {
      formatters_by_ft = {
        python = { "black", "isort" },
        sh = { "shfmt" },
        bash = { "shfmt" },
        lua = { "stylua" },
        json = { "prettier" },
        yaml = { "prettier" },
      },
      format_on_save = {
        timeout_ms = 500,
        lsp_fallback = true,
      },
    },
  },
}
EOF

# plugins/lint.lua
cat > "$NVIM_CONFIG/lua/plugins/lint.lua" << 'EOF'
return {
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "BufEnter" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        python = { "flake8" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
        yaml = { "yamllint" },
        json = { "jsonlint" },
      }
      vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "BufEnter" }, {
        callback = function() lint.try_lint() end,
      })
    end,
  },
}
EOF

# plugins/git.lua
cat > "$NVIM_CONFIG/lua/plugins/git.lua" << 'EOF'
return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {},
  },
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
}
EOF

# plugins/files.lua
cat > "$NVIM_CONFIG/lua/plugins/files.lua" << 'EOF'
return {
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      default_file_explorer = true,
    },
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
}
EOF

# plugins/aerial.lua
cat > "$NVIM_CONFIG/lua/plugins/aerial.lua" << 'EOF'
return {
  {
    "stevearc/aerial.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<F7>", "<cmd>AerialToggle<cr>", desc = "Toggle Aerial" },
    },
    opts = {
      layout = {
        width = 35,
        default_direction = "right",
      },
      attach_mode = "global",
    },
  },
}
EOF

# plugins/tagbar.lua
cat > "$NVIM_CONFIG/lua/plugins/tagbar.lua" << 'EOF'
return {
  {
    "preservim/tagbar",
    cmd = "TagbarToggle",
    keys = {
      { "<F8>", "<cmd>TagbarToggle<cr>", desc = "Toggle Tagbar" },
    },
    init = function()
      vim.g.tagbar_width = 35
      vim.g.tagbar_sort = 0
    end,
  },
}
EOF

# plugins/diffview.lua
cat > "$NVIM_CONFIG/lua/plugins/diffview.lua" << 'EOF'
return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff view" },
      { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
    },
  },
}
EOF

# plugins/telescope.lua
cat > "$NVIM_CONFIG/lua/plugins/telescope.lua" << 'EOF'
return {
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },
}
EOF

# plugins/render-markdown.lua
cat > "$NVIM_CONFIG/lua/plugins/render-markdown.lua" << 'EOF'
return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      file_types = { "markdown" },
    },
  },
}
EOF

# plugins/cheatsheet.lua
cat > "$NVIM_CONFIG/lua/plugins/cheatsheet.lua" << 'EOF'
return {
  {
    dir = vim.fn.stdpath("config"),
    name = "cheatsheet",
    lazy = true,
    keys = {
      {
        "<leader>?",
        function()
          local file = vim.fn.stdpath("config") .. "/cheatsheet.md"
          local buf = vim.api.nvim_create_buf(false, true)
          local lines = vim.fn.readfile(file)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          vim.bo[buf].filetype = "markdown"
          local width = math.floor(vim.o.columns * 0.8)
          local height = math.floor(vim.o.lines * 0.8)
          vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = width,
            height = height,
            row = math.floor((vim.o.lines - height) / 2),
            col = math.floor((vim.o.columns - width) / 2),
            style = "minimal",
            border = "rounded",
            title = " Cheatsheet ",
            title_pos = "center",
          })
          vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
          vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
        end,
        desc = "Cheatsheet",
      },
    },
  },
}
EOF

# cheatsheet.md
cat > "$NVIM_CONFIG/cheatsheet.md" << 'EOF'
# Neovim Keybindings

> `Space` = `<leader>`

## Window Navigation

| Key | Action |
|-----|--------|
| `Ctrl+h` | Move to left window |
| `Ctrl+j` | Move to bottom window |
| `Ctrl+k` | Move to top window |
| `Ctrl+l` | Move to right window |

## Window Management

| Key | Action |
|-----|--------|
| `\` | Split horizontal |
| `\|` | Split vertical |
| `Space+h` | Terminal below |

## Buffers

| Key | Action |
|-----|--------|
| `Tab` | Next buffer |
| `Shift+Tab` | Previous buffer |
| `Space+bd` | Delete buffer |

## File Manager

| Key | Action |
|-----|--------|
| `Space+e` | Oil (file manager) |
| `F7` | Toggle Aerial |
| `F8` | Toggle Tagbar |

## Git

| Key | Action |
|-----|--------|
| `Space+gg` | LazyGit |
| `Space+gp` | Preview hunk |
| `Space+gb` | Blame line |
| `Space+gd` | Diffview open |
| `Space+gh` | File history |

## LSP

| Key | Action |
|-----|--------|
| `Space+lf` | Format file |
| `Space+la` | Code action |
| `Space+lr` | Rename symbol |
| `Space+ld` | Show diagnostics |
| `gd` | Go to definition |
| `K` | Hover info |

## Search

| Key | Action |
|-----|--------|
| `Space+ff` | Find files |
| `Space+fg` | Live grep |
| `Space+fb` | Buffers |
| `Space+fo` | Recent files |
| `Space+f/` | Search in buffer |
| `Space+fk` | Keymaps |
| `Space+fm` | Marks |

## DevOps

| Key | Action |
|-----|--------|
| `Space+fs` | Document symbols |
| `Space+fr` | References |
| `Space+fd` | Diagnostics |
| `Space+fc` | Git commits |
| `Space+fB` | Git branches |
| `Space+fS` | Git status |
| `Space+fT` | Git stash |
| `Space+fp` | Projects |

## System

| Key | Action |
|-----|--------|
| `Space+fM` | Man pages |
| `Space+fe` | Environment variables |
| `Space+fh` | Help tags |
| `Space+md` | Toggle markdown render |
| `Space+?` | This cheatsheet |
EOF


cat > ~/.config/nvim/lua/plugins/toggleterm.lua << 'EOF'
return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "`", "<cmd>ToggleTerm direction=horizontal<cr>", desc = "Toggle terminal" },
    },
    opts = {
      size = 15,
      open_mapping = [[`]],
      direction = "horizontal",
      float_opts = {
        border = "rounded",
      },
    },
  },
}
EOF

cat >> setup-nvim.sh << 'APPEND'

# plugins/neotree.lua
cat > "$NVIM_CONFIG/lua/plugins/neotree.lua" << 'EOF'
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>E", "<cmd>Neotree toggle<cr>", desc = "Toggle Neo-tree" },
    },
    opts = {
      window = {
        position = "left",
        width = 35,
      },
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
        follow_current_file = {
          enabled = true,
        },
      },
    },
  },
}
EOF
APPEND

echo "Done. Run: nvim"
SCRIPT

chmod +x setup-nvim.sh

