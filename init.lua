-- =========================
-- Minimal Neovim Lua setup
-- lazy.nvim + new LSP API (0.11+)
-- =========================

-- ---------- Basics ----------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.number = true
o.relativenumber = false
o.mouse = "a"
o.clipboard = "unnamedplus"
o.ignorecase = true
o.smartcase = true
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.termguicolors = true
o.signcolumn = "yes"
o.splitright = true
o.splitbelow = true
o.updatetime = 250
o.wrap = false
o.sidescroll = 1
o.sidescrolloff = 8
o.virtualedit = "onemore"

-- Small QoL keymaps
local map = vim.keymap.set
-- Make ctrl-z function like it does normally
map("n", "<C-z>", "u", { desc = "Undo" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo (Insert mode)" })
-- Allow backspace to delete selected text in Visual mode
map("x", "<BS>", '"_d', { desc = "Delete selection with backspace" })

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>")
map("n", "<leader>e", function()
  vim.diagnostic.open_float(nil, { focus = false, scope = "cursor" })
end, { desc = "Line diagnostics" })

-- Open a full-screen terminal that restores your previous buffer when closed
vim.keymap.set("n", "<leader>t", function()
  -- Save the current window view
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()

  -- Open a new full-screen terminal buffer
  vim.cmd("terminal")

  -- When the terminal buffer is closed, return to previous buffer
  vim.api.nvim_create_autocmd("TermClose", {
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(current_buf) and vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
        vim.api.nvim_set_current_buf(current_buf)
      end
    end,
  })

  -- Start in insert mode for immediate terminal input
  vim.cmd("startinsert")
end, { desc = "Open full-screen terminal" })

-- Force Neovim to use wl-clipboard
vim.g.clipboard = {
  name = "wl-clipboard",
  copy = {
    ["+"] = { "wl-copy", "--foreground", "--type", "text/plain" },
    ["*"] = { "wl-copy", "--foreground", "--primary", "--type", "text/plain" },
  },
  paste = {
    ["+"] = { "wl-paste", "--no-newline" },
    ["*"] = { "wl-paste", "--primary", "--no-newline" },
  },
  cache_enabled = 1,
}

-- Use Ctrl+C / Ctrl+V for copy/paste like VS Code
-- (works in normal, visual, and insert modes)

-- Copy to system clipboard
vim.keymap.set({ "n", "x" }, "<C-c>", '"+y', { desc = "Copy to system clipboard" })

-- Paste from system clipboard
vim.keymap.set({ "n", "x" }, "<C-v>", '"+p', { desc = "Paste from system clipboard" })

-- Paste in insert mode
vim.keymap.set("i", "<C-v>", '<C-r>+', { desc = "Paste from system clipboard" })

-- ---------- Bootstrap lazy.nvim ----------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ---------- Plugins ----------
require("lazy").setup({
  -- Utility
  { "nvim-lua/plenary.nvim",       lazy = true },

  -- Appearance
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {}, -- you can pass options here
    config = function()
      vim.g.tokyonight_transparent = true
      vim.g.tokyonight_transparent_sidebar = true
      vim.cmd.colorscheme("tokyonight")

      -- Extra safeguard: clear background of standard highlight groups
      for _, group in ipairs({
        "Normal", "NormalNC", "NormalFloat", "FloatBorder",
        "SignColumn", "LineNr", "EndOfBuffer"
      }) do
        vim.api.nvim_set_hl(0, group, { bg = "none" })
      end
    end,
  },

  { "nvim-tree/nvim-web-devicons", lazy = true },

  {
    "nvim-lualine/lualine.nvim",
    config = function()
      require("lualine").setup({ options = { theme = "auto" } })
    end
  },

  -- Finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope")

      telescope.setup({})

      local map = vim.keymap.set
      map("n", "<leader>ff", "<cmd>Telescope find_files hidden=true no_ignore=true<cr>", { desc = "Find files" })
      map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
      map("n", "<leader>fb", "<cmd>Telescope buffers<cr>", { desc = "Buffers" })
      map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>", { desc = "Help" })
    end
  },

  -- Treesitter (better syntax/indent)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "lua", "vim", "vimdoc", "bash", "python", "json", "c", "cpp", },
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },

  -- LSP infra (we'll use the new vim.lsp.config API below)
  { "neovim/nvim-lspconfig" }, -- still provides defaults/metadata
  { "williamboman/mason.nvim", config = function() require("mason").setup() end },
  {
    "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        -- IMPORTANT: use lspconfig server names; TypeScript is "ts_ls"
        ensure_installed = { "lua_ls", "clangd" },
      })
    end
  },

  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      local npairs = require("nvim-autopairs")
      npairs.setup({
        check_ts = true, -- enables Treesitter-based rules for better context
        fast_wrap = {},  -- optional: allows wrapping existing text
      })

      -- Optional: integrate with nvim-cmp completion
      local ok, cmp = pcall(require, "cmp")
      if ok then
        local cmp_autopairs = require("nvim-autopairs.completion.cmp")
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
      end
    end,
  },

  {
    "ray-x/lsp_signature.nvim",
    event = "VeryLazy",
    config = function()
      require("lsp_signature").setup({
        bind = true,
        hint_enable = true, -- virtual hint inline
        floating_window = true, -- show popup window
        handler_opts = { border = "rounded" },
        hint_prefix = "🐍 ", -- change the icon if you want
        toggle_key = "<M-x>", -- Alt-x to toggle display
        zindex = 50, -- ensure it’s above other floats
      })
    end,
  },

  -- Completion (nvim-cmp) with LSP source + snippets
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
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args) luasnip.lsp_expand(args.body) end,
        },

        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(), -- cancel
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<Esc>"] = cmp.mapping({
            i = function(fallback)
              if cmp.visible() then
                cmp.abort()
              else
                fallback()
              end
            end,
            c = function(fallback)
              fallback()
            end,
          }),
        }),

        sources = {
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
          { name = "buffer" },
        },
      })
    end
  },
}, {
  ui = { border = "rounded" },
})

-- ---------- New LSP API (Neovim 0.11+) ----------
-- Global/base config for all LSPs
vim.lsp.config('*', {
  on_attach = function(_, bufnr)
    local mapb = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end
    mapb("n", "gd", vim.lsp.buf.definition, "Go to definition")
    mapb("n", "gr", vim.lsp.buf.references, "References")
    mapb("n", "K", vim.lsp.buf.hover, "Hover")
    mapb("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
    mapb("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
    mapb("n", "<leader>e", vim.diagnostic.open_float, "Line diagnostics")
    mapb("n", "[d", vim.diagnostic.goto_prev, "Prev diagnostic")
    mapb("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
    vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
  end,

  capabilities = (function()
    local caps = vim.lsp.protocol.make_client_capabilities()
    local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
    if ok then caps = cmp_lsp.default_capabilities(caps) end
    return caps
  end)(),
})

-- Server-specific tweaks/overrides (merged with the global '*')
vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false },
    }
  }
})

-- LSP config for clangd specifically
vim.lsp.config("clangd", {
  cmd = { "/usr/bin/clangd", "--enable-config", "--background-index", "--clang-tidy", "-header-insertion=iwyu" },

  filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto", "hpp", "ixx", "mpp" },
})

-- Enable servers
for _, server in ipairs({ "lua_ls", "clangd" }) do
  vim.lsp.enable(server)
end

-- 4-space indent for c/c++ buffers
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "objc", "objcpp" },
  callback = function()
    vim.bo.shiftwidth = 4
    vim.bo.tabstop = 4
    vim.bo.softtabstop = 4
    vim.bo.expandtab = true
    -- optional C indentation helpers:
    vim.bo.cindent = true
  end,
})

-- Adds a border to diagnostic windows to differentiate it from text
vim.diagnostic.config({
  virtual_text = {
    prefix = "●",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,

  float = {
    border = "rounded", -- options: "single", "double", "rounded", "solid", "shadow"
    focusable = false,
    style = "minimal",
    source = "always", -- show "Error [pyright]" in popup
    header = "",
    prefix = "",
  },
})

-- <leader>cf in NORMAL mode -> whole buffer
vim.keymap.set("n", "<leader>cf", function()
  vim.lsp.buf.format({ async = true })
end, { desc = "Format buffer with LSP" })


