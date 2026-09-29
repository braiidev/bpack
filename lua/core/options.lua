-- Opciones base. Sin plugins: si algo necesita un plugin, no vive acá.
--
-- Todo se declara en una tabla para que la superficie sea legible de un vistazo
-- y para que `bpack doctor` pueda verificarla sin adivinar.

local M = {}

--- Opciones globales, en la forma que las toma `vim.opt`.
--- El valor `true`/`false` se aplica tal cual; el resto se pasa por `:`.
--- @type table<string, boolean|string|integer>
M.options = {
  -- Presentación
  number = true,
  relativenumber = true,
  cursorline = true,
  cursorcolumn = false,
  signcolumn = "yes",
  showmode = false,
  laststatus = 3,
  showtabline = 2,
  splitkeep = "screen",
  scrolloff = 0,
  wrap = true,
  linebreak = true,
  breakindent = true,
  display = { "lastline" },

  -- Sangría. 2 por defecto; python pide 4 y lo ajusta `core.autocmds` por
  -- filetype, porque en este repo la excepcion es el punto.
  tabstop = 2,
  shiftwidth = 2,
  softtabstop = 2,
  expandtab = true,
  autoindent = true,
  smartindent = true,
  shiftround = true,

  -- Búsqueda
  ignorecase = true,
  smartcase = true,
  incsearch = true,
  hlsearch = true,

  -- Split
  splitbelow = true,
  splitright = true,

  -- Historial
  undofile = true,
  undolevels = 10000,

  -- Comportamiento
  hidden = true,
  mouse = "a",
  termguicolors = true,
  timeoutlen = 400,
  updatetime = 250,
  completeopt = "menu,menuone,noselect",
  wildmenu = true,
  smarttab = true,
  ttimeout = true,
  ttimeoutlen = 10,

  -- Identificadores: guion y underscore cuentan como parte del nombre, que es
  -- lo que hacen LSP y treesitter al saltar a una definición.
  iskeyword = "-,48-57,_,192-255",

  -- Colores
  list = false,
  listchars = { tab = "» ", trail = "·", nbsp = "␣" },
}

--- Sangría por filetype. La global es 2 (Lua, JS, TS, JSON, YAML, web); Python
--- y los formatos que forcing un tabulador de 8 cambian acá.
--- @type table<string, { tabstop?: integer, shiftwidth?: integer, expandtab?: boolean, softtabstop?: integer }>
M.indent_by_ft = {
  python = { tabstop = 4, shiftwidth = 4, softtabstop = 4 },
  make = { tabstop = 8, shiftwidth = 8, softtabstop = 0, expandtab = false },
  gitcommit = { tabstop = 8, shiftwidth = 8, softtabstop = 0, expandtab = false },
  help = { tabstop = 8, shiftwidth = 8, softtabstop = 0, expandtab = false },
}

--- Habilita `unnamedplus` solo si hay un proveedor de clipboard en el sistema.
--- Ponerlo a secas rompe el `y` en sesiones sin X11 ni Wayland.
--- @return boolean ok
local function setup_clipboard()
  for _, p in ipairs({ "xclip", "xsel", "wl-copy", "win32yank.exe" }) do
    if vim.fn.executable(p) == 1 then
      vim.opt.clipboard = "unnamedplus"
      return true
    end
  end
  return false
end

function M.setup()
  for opt, value in pairs(M.options) do
    vim.opt[opt] = value
  end

  setup_clipboard()
  return true
end

return M
