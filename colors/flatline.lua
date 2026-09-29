-- Flatline: el colorscheme de bpack.
--
-- Paleta de la CSS de Flatline. Es el tema por defecto, y el que se carga si
-- el usuario nunca eligió otro: el repo no puede depender de que haya un tema
-- de plugin instalado.
--
-- Si `flatline` fuera sólo un colorscheme más, `bpack theme` no valdría. Lo que
-- lo hace útil es que expone la paleta: el resto de la config (lualine, luego)
-- lee estos mismos valores en vez de duplicar códigos de color.

local M = {}

M.palette = {
  bg = "#1a1d23",
  surface = "#2a2e38",
  surface_alt = "#323742",
  text = "#c4c7cc",
  text_dim = "#7a88a0",

  teal = "#5fa8a0",
  terracotta = "#b87a6b",

  slate = "#7a88a0",
  sage = "#6b8577",
  steel = "#5f7fa8",

  mustard = "#b8a15f",
  clay = "#b87f5f",
  mauve = "#8b7a99",
  plum = "#b87a99",
}

local p = M.palette
local hl = vim.api.nvim_set_hl

vim.g.colors_name = "flatline"

-- ── Base ───────────────────────────────────────────────────────────────────
hl(0, "Normal", { fg = p.text, bg = p.bg })
hl(0, "NormalNC", { fg = p.text_dim, bg = p.bg })
hl(0, "NormalFloat", { fg = p.text, bg = p.surface })
hl(0, "FloatBorder", { fg = p.slate, bg = p.surface })
hl(0, "FloatTitle", { fg = p.text, bg = p.surface, bold = true })
hl(0, "FloatFooter", { fg = p.slate, bg = p.surface })
hl(0, "ColorColumn", { bg = p.surface })
hl(0, "Cursor", { fg = p.bg, bg = p.teal })
hl(0, "lCursor", { fg = p.bg, bg = p.teal })
hl(0, "CursorLine", { bg = p.surface })
hl(0, "CursorLineNr", { fg = p.teal, bold = true })
hl(0, "CursorLineSign", { fg = p.teal, bg = p.surface })
hl(0, "CursorLineFold", { fg = p.teal, bg = p.surface })
hl(0, "LineNr", { fg = p.slate })
hl(0, "SignColumn", { fg = p.slate, bg = p.bg })
hl(0, "FoldColumn", { fg = p.slate, bg = p.bg })
hl(0, "Folded", { fg = p.slate, bg = p.surface })
hl(0, "NonText", { fg = p.slate })
hl(0, "Whitespace", { fg = p.slate })
hl(0, "SpecialKey", { fg = p.slate })
hl(0, "Conceal", { fg = p.slate })
hl(0, "EndOfBuffer", { fg = p.bg })
hl(0, "VertSplit", { fg = p.surface })
hl(0, "WinSeparator", { fg = p.surface })
hl(0, "Title", { fg = p.teal, bold = true })
hl(0, "Directory", { fg = p.steel })
hl(0, "Search", { fg = p.bg, bg = p.mustard })
hl(0, "IncSearch", { fg = p.bg, bg = p.mustard, bold = true })
hl(0, "CurSearch", { fg = p.bg, bg = p.teal })
hl(0, "Substitute", { fg = p.bg, bg = p.terracotta })
hl(0, "QuickFixLine", { bg = p.surface, bold = true })
hl(0, "StatusLine", { fg = p.text, bg = p.surface })
hl(0, "StatusLineNC", { fg = p.text_dim, bg = p.bg })
hl(0, "TabLine", { fg = p.text_dim, bg = p.bg })
hl(0, "TabLineFill", { bg = p.bg })
hl(0, "TabLineSel", { fg = p.text, bg = p.surface, bold = true })
hl(0, "MatchParen", { bg = p.surface, bold = true })

-- ── Visual ─────────────────────────────────────────────────────────────────
hl(0, "Visual", { bg = p.surface, bold = true })
hl(0, "VisualNOS", { bg = p.surface, underline = true })

-- ── Mensajes y diagnósticos ────────────────────────────────────────────────
hl(0, "MsgArea", { fg = p.text, bg = p.bg })
hl(0, "ModeMsg", { fg = p.teal, bold = true })
hl(0, "MsgSeparator", { fg = p.slate })
hl(0, "MoreMsg", { fg = p.teal })
hl(0, "Question", { fg = p.teal })
hl(0, "WarningMsg", { fg = p.mustard })
hl(0, "ErrorMsg", { fg = p.terracotta })
hl(0, "DiagnosticError", { fg = p.terracotta })
hl(0, "DiagnosticWarn", { fg = p.mustard })
hl(0, "DiagnosticInfo", { fg = p.steel })
hl(0, "DiagnosticHint", { fg = p.slate })
hl(0, "DiagnosticOk", { fg = p.sage })

-- ── Menú de completados ────────────────────────────────────────────────────
hl(0, "Pmenu", { fg = p.text, bg = p.surface })
hl(0, "PmenuSel", { fg = p.bg, bg = p.teal, bold = true })
hl(0, "PmenuSbar", { bg = p.surface })
hl(0, "PmenuThumb", { bg = p.slate })

-- ── Spell ──────────────────────────────────────────────────────────────────
hl(0, "SpellBad", { undercurl = true, sp = p.terracotta })
hl(0, "SpellCap", { undercurl = true, sp = p.steel })
hl(0, "SpellLocal", { undercurl = true, sp = p.teal })
hl(0, "SpellRare", { undercurl = true, sp = p.mauve })

-- ── Diagnósticos y diff ────────────────────────────────────────────────────
hl(0, "DiagnosticUnderlineError", { undercurl = true, sp = p.terracotta })
hl(0, "DiagnosticUnderlineWarn", { undercurl = true, sp = p.mustard })
hl(0, "DiagnosticUnderlineInfo", { undercurl = true, sp = p.steel })
hl(0, "DiagnosticUnderlineHint", { undercurl = true, sp = p.slate })
hl(0, "DiagnosticVirtualTextError", { fg = p.terracotta, bg = p.bg })
hl(0, "DiagnosticVirtualTextWarn", { fg = p.mustard, bg = p.bg })
hl(0, "DiagnosticVirtualTextInfo", { fg = p.steel, bg = p.bg })
hl(0, "DiagnosticVirtualTextHint", { fg = p.slate, bg = p.bg })
hl(0, "DiagnosticSignError", { fg = p.terracotta })
hl(0, "DiagnosticSignWarn", { fg = p.mustard })
hl(0, "DiagnosticSignInfo", { fg = p.steel })
hl(0, "DiagnosticSignHint", { fg = p.slate })
hl(0, "DiagnosticSignOk", { fg = p.sage })

hl(0, "DiffAdd", { fg = p.sage, bg = p.surface })
hl(0, "DiffChange", { fg = p.mustard, bg = p.surface })
hl(0, "DiffDelete", { fg = p.terracotta, bg = p.surface })
hl(0, "DiffText", { fg = p.teal, bg = p.surface })
hl(0, "diffAdded", { fg = p.sage })
hl(0, "diffRemoved", { fg = p.terracotta })
hl(0, "diffChanged", { fg = p.mustard })
hl(0, "diffDeleted", { fg = p.terracotta })
hl(0, "diffFile", { fg = p.teal })
hl(0, "diffLine", { fg = p.slate })

-- ── Sintaxis classic ───────────────────────────────────────────────────────
hl(0, "Comment", { fg = p.slate, italic = true })
hl(0, "Constant", { fg = p.clay })
hl(0, "String", { fg = p.sage })
hl(0, "Character", { fg = p.clay })
hl(0, "Number", { fg = p.clay })
hl(0, "Boolean", { fg = p.teal })
hl(0, "Float", { fg = p.clay })
hl(0, "Identifier", { fg = p.plum })
hl(0, "Function", { fg = p.teal })
hl(0, "Statement", { fg = p.mauve })
hl(0, "Conditional", { fg = p.mauve })
hl(0, "Repeat", { fg = p.mauve })
hl(0, "Label", { fg = p.steel })
hl(0, "Operator", { fg = p.text })
hl(0, "Keyword", { fg = p.mauve })
hl(0, "Exception", { fg = p.mauve })
hl(0, "PreProc", { fg = p.teal })
hl(0, "Include", { fg = p.teal })
hl(0, "Define", { fg = p.mauve })
hl(0, "Macro", { fg = p.plum })
hl(0, "PreCondit", { fg = p.mauve })
hl(0, "Type", { fg = p.steel })
hl(0, "StorageClass", { fg = p.steel })
hl(0, "Structure", { fg = p.steel })
hl(0, "Typedef", { fg = p.steel })
hl(0, "Special", { fg = p.mustard })
hl(0, "SpecialChar", { fg = p.mustard })
hl(0, "Tag", { fg = p.teal })
hl(0, "Delimiter", { fg = p.slate })
hl(0, "SpecialComment", { fg = p.slate, italic = true })
hl(0, "Debug", { fg = p.terracotta })
hl(0, "Underlined", { underline = true })
hl(0, "Ignore", { fg = p.slate })
hl(0, "Error", { fg = p.terracotta })
hl(0, "Todo", { fg = p.mustard, bold = true })

-- ── Treesitter ─────────────────────────────────────────────────────────────
hl(0, "@variable", { fg = p.text })
hl(0, "@variable.builtin", { fg = p.terracotta })
hl(0, "@variable.parameter", { fg = p.plum })
hl(0, "@variable.member", { fg = p.text })
hl(0, "@constant", { fg = p.clay })
hl(0, "@constant.builtin", { fg = p.teal })
hl(0, "@constant.macro", { fg = p.clay })
hl(0, "@module", { fg = p.steel })
hl(0, "@module.builtin", { fg = p.steel })
hl(0, "@string.regexp", { fg = p.mustard })
hl(0, "@string.escape", { fg = p.mustard })
hl(0, "@string.special", { fg = p.mustard })
hl(0, "@character.special", { fg = p.mustard })
hl(0, "@number", { fg = p.clay })
hl(0, "@number.float", { fg = p.clay })
hl(0, "@boolean", { fg = p.teal })
hl(0, "@type", { fg = p.steel })
hl(0, "@type.builtin", { fg = p.steel })
hl(0, "@type.definition", { fg = p.steel })
hl(0, "@attribute", { fg = p.teal })
hl(0, "@property", { fg = p.text })
hl(0, "@function", { fg = p.teal })
hl(0, "@function.builtin", { fg = p.teal })
hl(0, "@function.call", { fg = p.teal })
hl(0, "@function.macro", { fg = p.plum })
hl(0, "@function.method", { fg = p.teal })
hl(0, "@function.method.call", { fg = p.teal })
hl(0, "@constructor", { fg = p.teal })
hl(0, "@operator", { fg = p.text })
hl(0, "@keyword", { fg = p.mauve })
hl(0, "@keyword.coroutine", { fg = p.mauve })
hl(0, "@keyword.function", { fg = p.mauve })
hl(0, "@keyword.operator", { fg = p.mauve })
hl(0, "@keyword.import", { fg = p.teal })
hl(0, "@keyword.type", { fg = p.steel })
hl(0, "@keyword.modifier", { fg = p.steel })
hl(0, "@keyword.repeat", { fg = p.mauve })
hl(0, "@keyword.return", { fg = p.mauve })
hl(0, "@keyword.debug", { fg = p.terracotta })
hl(0, "@keyword.exception", { fg = p.mauve })
hl(0, "@keyword.conditional", { fg = p.mauve })
hl(0, "@keyword.directive", { fg = p.mauve })
hl(0, "@keyword.directive.define", { fg = p.mauve })
hl(0, "@punctuation.delimiter", { fg = p.slate })
hl(0, "@punctuation.bracket", { fg = p.slate })
hl(0, "@punctuation.special", { fg = p.slate })
hl(0, "@comment", { fg = p.slate, italic = true })
hl(0, "@comment.documentation", { fg = p.slate, italic = true })
hl(0, "@comment.error", { fg = p.terracotta, italic = true })
hl(0, "@comment.warning", { fg = p.mustard, italic = true })
hl(0, "@comment.todo", { fg = p.teal, bold = true })
hl(0, "@comment.note", { fg = p.steel, italic = true })
hl(0, "@markup.heading", { fg = p.teal, bold = true })
hl(0, "@markup.heading.1", { fg = p.teal, bold = true })
hl(0, "@markup.heading.2", { fg = p.steel, bold = true })
hl(0, "@markup.heading.3", { fg = p.mauve, bold = true })
hl(0, "@markup.heading.4", { fg = p.clay, bold = true })
hl(0, "@markup.strong", { bold = true })
hl(0, "@markup.italic", { italic = true })
hl(0, "@markup.strikethrough", { strikethrough = true })
hl(0, "@markup.underline", { underline = true })
hl(0, "@markup.link", { fg = p.steel })
hl(0, "@markup.link.label", { fg = p.plum })
hl(0, "@markup.link.url", { fg = p.slate, underline = true })
hl(0, "@markup.raw", { fg = p.clay })
hl(0, "@markup.list", { fg = p.teal })
hl(0, "@markup.list.checked", { fg = p.sage })
hl(0, "@markup.list.unchecked", { fg = p.slate })

-- ── LSP ────────────────────────────────────────────────────────────────────
hl(0, "@lsp.type.class", { fg = p.steel })
hl(0, "@lsp.type.enum", { fg = p.steel })
hl(0, "@lsp.type.enumMember", { fg = p.clay })
hl(0, "@lsp.type.interface", { fg = p.steel })
hl(0, "@lsp.type.struct", { fg = p.steel })
hl(0, "@lsp.type.typeParameter", { fg = p.steel })
hl(0, "@lsp.type.macro", { fg = p.plum })
hl(0, "@lsp.mod.deprecated", { strikethrough = true })

-- ── Neovim UI ──────────────────────────────────────────────────────────────
hl(0, "NormalSB", { fg = p.text, bg = p.teal, bold = true })
hl(0, "NormalFloatSB", { fg = p.bg, bg = p.teal, bold = true })
hl(0, "WinBar", { fg = p.text, bg = p.surface })
hl(0, "WinBarNC", { fg = p.text_dim, bg = p.bg })
hl(0, "TabLineSeparator", { fg = p.surface, bg = p.bg })
hl(0, "FloatShadow", { bg = p.surface, blend = 80 })
hl(0, "FloatShadowThrough", { bg = p.bg, blend = 80 })
hl(0, "LspInfoBorder", { fg = p.steel, bg = p.surface })
hl(0, "LspSignatureActiveParameter", { bg = p.surface, bold = true })
hl(0, "LspCodeLens", { fg = p.text_dim, italic = true })
hl(0, "LspInlayHint", { fg = p.text_dim, bg = p.bg })
hl(0, "LspReferenceText", { bg = p.surface })
hl(0, "LspReferenceTarget", { bg = p.surface, bold = true })
hl(0, "LspDiagnosticsDefaultError", { undercurl = true, sp = p.terracotta })

hl(0, "debugPC", { bg = p.surface })
hl(0, "debugBreakpoint", { fg = p.terracotta, bold = true })

-- ── Links, diagnósticos de segundo nivel y markup restante ────────────────
hl(0, "DiagnosticUnnecessary", { fg = p.text_dim, italic = true })
hl(0, "DiagnosticDeprecated", { strikethrough = true, sp = p.text_dim })
hl(0, "@tag.builtin", { fg = p.teal })
hl(0, "@attribute.builtin", { fg = p.teal })
hl(0, "@string.special.url", { fg = p.steel, underline = true })
hl(0, "@string.special.path", { fg = p.plum })

hl(0, "@markup.heading.5", { fg = p.clay, bold = true })
hl(0, "@markup.heading.6", { fg = p.slate, bold = true })
hl(0, "@markup.math", { fg = p.steel })
hl(0, "@markup.environment", { fg = p.sage })
hl(0, "@markup.quote", { fg = p.text_dim, italic = true })
hl(0, "@markup.emoji", { fg = p.clay })

return M
