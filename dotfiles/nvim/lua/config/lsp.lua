local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

capabilities.workspace = capabilities.workspace or {}
capabilities.workspace.didChangeWatchedFiles = {
  dynamicRegistration = true,
  relativePatternSupport = true,
}

vim.lsp.config("*", {
  capabilities = capabilities,
  root_markers = { ".git" },
})

vim.lsp.config("ts_ls", {
  root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
  init_options = {
    maxTsServerMemory = 8192,
    preferences = {
      includeCompletionsForModuleExports = true,
      includeCompletionsForImportStatements = true,
      includeCompletionsWithSnippetText = true,
      includeAutomaticOptionalChainCompletions = true,
      includeCompletionsWithInsertText = true,
    },
  },
  settings = {
    typescript = {
      tsserver = { useSyntaxServer = "auto" },
      suggest = { completeFunctionCalls = true },
      inlayHints = {
        includeInlayParameterNameHints = "literals",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = false,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
    javascript = {
      suggest = { completeFunctionCalls = true },
      inlayHints = {
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayEnumMemberValueHints = true,
      },
    },
  },
})

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = false,
        nilness = true,
        unusedwrite = true,
        useany = true,
        ST1000 = false,
        ST1003 = false,
        QF1008 = false,
      },
      staticcheck = true,
      gofumpt = true,
      usePlaceholders = true,
      completeUnimported = true,
      semanticTokens = true,
      -- Keep completions scoped to what was actually typed: deepCompletion
      -- pads qualified completions (e.g. `employee.`) with fuzzy-matched
      -- symbols from the current package.
      deepCompletion = false,
      directoryFilters = { "-**/node_modules", "-**/.git" },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        constantValues = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
})

-- PHP language semantics. Anchor the root at the Laravel project (artisan)
-- so a single workspace is indexed, and raise the file-size cap so large
-- generated files (e.g. laravel-ide-helper output) still get indexed.
vim.lsp.config("intelephense", {
  root_markers = { "composer.json", "artisan", ".git" },
  settings = {
    intelephense = {
      files = {
        maxSize = 5000000,
      },
    },
  },
})

-- Rust language semantics. nvim-lspconfig already anchors the root at the
-- Cargo workspace (it asks `cargo metadata`), so no root markers are needed.
vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      -- Run clippy instead of plain `cargo check` on save, so the buffer shows
      -- the same lints CI does rather than only compiler errors.
      check = {
        command = "clippy",
      },
    },
  },
})

-- English language semantics. The `els` binary ships with the language's own
-- toolchain (built from this repo: `go build -o ~/.local/bin/els ./cmd/els`),
-- so Mason must not install a second copy. It serves whatever .en file is
-- open, so only the source marker is needed for a sensible root.
vim.lsp.config("english", {
  cmd = { "els" },
  root_markers = { "index.en" },
  filetypes = { "english" },
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.en" },
  callback = function()
    vim.bo.filetype = "english"
  end,
})

-- Servers Mason downloads and keeps up to date.
local lsp_servers = {
  "cssls",
  "docker_compose_language_service",
  "dockerls",
  "eslint",
  "gopls",
  "intelephense",
  "tailwindcss",
  "templ",
  "ts_ls",
}

-- Servers that ship with the language's own toolchain, so Mason must not
-- install a second copy. rust-analyzer comes from rustup
-- (`rustup component add rust-analyzer`), which keeps it matched to the
-- compiler the project is actually built with.
local toolchain_servers = {
  "rust_analyzer",
  "english",
}

require("mason-lspconfig").setup {
  ensure_installed = lsp_servers,
}

local navic = require("nvim-navic")

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
    local bufnr = args.buf

    if client.server_capabilities.documentSymbolProvider then
      navic.attach(client, bufnr)
    end

    if client.name == "eslint" then
      vim.keymap.set("n", "<leader>fa", function()
        vim.lsp.buf.code_action({
          apply = true,
          context = { diagnostics = {}, only = { "source.fixAll" } },
        })
      end, { buffer = bufnr, noremap = true, silent = true, desc = "Fix all ESLint issues" })
    end
  end,
})

vim.lsp.enable(lsp_servers)
vim.lsp.enable(toolchain_servers)
