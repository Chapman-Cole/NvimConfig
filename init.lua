-- =========================
-- Minimal Neovim Lua setup
-- lazy.nvim + new LSP API (0.11+)
-- =========================

-- ---------- Basics ----------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.number = true
o.relativenumber = true
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

-- Small QoL keymaps
local map = vim.keymap.set
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<Esc>", "<cmd>nohlsearch<cr>")

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
  { "nvim-lua/plenary.nvim", lazy = true },

  -- Appearance
  { "ellisonleao/gruvbox.nvim", priority = 1000, config = function()
      vim.cmd.colorscheme("gruvbox")
    end
  },
  { "nvim-tree/nvim-web-devicons", lazy = true },
  { "nvim-lualine/lualine.nvim", config = function()
      require("lualine").setup({ options = { theme = "auto" } })
    end
  },

  -- Finder
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local telescope = require("telescope")
      telescope.setup({})
      local map = vim.keymap.set
      map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find files" })
      map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Live grep" })
      map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",    { desc = "Buffers" })
      map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>",  { desc = "Help" })
    end
  },

  -- Treesitter (better syntax/indent)
  { "nvim-treesitter/nvim-treesitter",
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
  { "williamboman/mason-lspconfig.nvim",
    config = function()
      require("mason-lspconfig").setup({
        -- IMPORTANT: use lspconfig server names; TypeScript is "ts_ls"
        ensure_installed = { "lua_ls", "clangd" },
      })
    end
  },

  -- Completion (nvim-cmp) with LSP source + snippets
  { "hrsh7th/nvim-cmp",
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
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
            else fallback() end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then luasnip.jump(-1)
            else fallback() end
          end, { "i", "s" }),
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
    mapb("n", "gd", vim.lsp.buf.definition,           "Go to definition")
    mapb("n", "gr", vim.lsp.buf.references,           "References")
    mapb("n", "K",  vim.lsp.buf.hover,                "Hover")
    mapb("n", "<leader>rn", vim.lsp.buf.rename,       "Rename")
    mapb("n", "<leader>ca", vim.lsp.buf.code_action,  "Code Action")
    mapb("n", "<leader>e",  vim.diagnostic.open_float,"Line diagnostics")
    mapb("n", "[d", vim.diagnostic.goto_prev,         "Prev diagnostic")
    mapb("n", "]d", vim.diagnostic.goto_next,         "Next diagnostic")
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
  cmd = {"clangd", "--fallback-style={BasedOnStyle: LLVM, IndentWidth: 4}"},
})

vim.lsp.config("pyright", {})  -- defaults are fine
vim.lsp.config("ts_ls", {})    -- TypeScript/JavaScript (typescript-language-server)

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
