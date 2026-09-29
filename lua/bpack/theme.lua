-- Temas: aplicar, cambiar y recordar.
--
-- La elección se persiste en `state.json` y se vuelve a aplicar en cada
-- arranque. Ese es el punto: cambiar de tema no es un `:colorscheme` suelto que
-- se pierde al cerrar, es una decisión de la instalación.
--
-- El default es `flatline`, que va en el repo. Si el default fuera un tema de
-- plugin, un clone nuevo sin instalar plugins arrancaría sin color.

local cmd = require("bpack.cmd")
local state = require("bpack.state")
local util = require("bpack.util")

local M = {}

--- Tema por defecto. Va en el repo, así que funciona sin plugins.
M.default = "flatline"

--- Clave de estado donde se guarda la elección.
M.state_key = "theme"

--- Directorio de este config, para distinguir nuestros colorschemes de los de
--- los plugins en el listado.
--- @return string
local function config_root()
  return vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
end

--- De dónde sale un colorscheme, para el listado: los nuestros, los que trae
--- Neovim, o los que aporta un plugin.
--- @param path string
--- @return "bpack"|"nvim"|"plugin"
function M.origin(path)
  if path:sub(1, #config_root()) == config_root() then
    return "bpack"
  end
  local runtime = vim.env.VIMRUNTIME
  if runtime and runtime ~= "" and path:sub(1, #runtime) == runtime then
    return "nvim"
  end
  return "plugin"
end

--- Todos los colorschemes que se pueden aplicar.
---
--- Se leen del rtp, así que incluye los que traen los plugins ya instalados: no
--- hace falta mantener una lista a mano que se desactualiza al primer update.
--- @return {name: string, path: string, origin: string}[]
function M.available()
  local seen, out = {}, {}
  for _, path in ipairs(vim.api.nvim_get_runtime_file("colors/*.lua", true)) do
    local name = vim.fn.fnamemodify(path, ":t:r")
    if not seen[name] then
      seen[name] = true
      out[#out + 1] = { name = name, path = path, origin = M.origin(path) }
    end
  end
  table.sort(out, function(a, b)
    local rank = { bpack = 1, nvim = 2, plugin = 3 }
    if rank[a.origin] ~= rank[b.origin] then
      return rank[a.origin] < rank[b.origin]
    end
    return a.name < b.name
  end)
  return out
end

--- ¿Existe un colorscheme con ese nombre?
--- @param name string
--- @return boolean
function M.exists(name)
  for _, t in ipairs(M.available()) do
    if t.name == name then
      return true
    end
  end
  return false
end

--- El tema aplicado ahora.
--- @return string|nil
function M.current()
  return vim.g.colors_name
end

--- Aplica un tema sin persistirlo.
---
--- Devuelve `false` en vez de tirar si el colorscheme falla: un `error()` en
--- `hi` deja al usuario con una ventana sin highlighting y sin explicación.
--- @param name string
--- @return boolean ok
function M.apply(name)
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    util.log("colorscheme %s fallo: %s", name, tostring(err))
    util.notify(("no se pudo aplicar '%s': %s"):format(name, tostring(err)), vim.log.levels.ERROR)
    return false
  end
  -- `colorscheme` ya dispara `ColorScheme`, así que lualine y los demás se
  -- re-sincronizan solos. No hace falta re-emitirlo.
  util.log("tema aplicado: %s", name)
  return true
end

--- Aplica un tema y lo persiste.
--- @param name string
--- @return boolean ok
function M.set(name)
  if not M.apply(name) then
    return false
  end
  state.set(M.state_key, name)
  util.notify("tema: " .. name)
  return true
end

--- El tema elegido, o el default si nunca se eligió uno.
--- @return string
function M.preferred()
  return state.get(M.state_key, M.default)
end

--- Selector interactivo. `1`-`9` y `<CR>` eligen.
local function picker()
  local themes = M.available()
  if #themes == 0 then
    util.notify("no hay colorschemes disponibles")
    return
  end

  local current = M.current()
  local lines = {}
  for i, t in ipairs(themes) do
    local mark = t.name == current and "●" or " "
    local idx = i <= 9 and tostring(i) or " "
    lines[#lines + 1] = ("  %s  %s  %-28s %s"):format(idx, mark, t.name, t.origin)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  1-9 o <CR> para elegir · q para cerrar"

  local function pick(i)
    local t = themes[i]
    if not t then
      return
    end
    -- Cierra primero: aplicar un tema repinta la ventana donde estamos.
    vim.cmd("close")
    M.set(t.name)
  end

  local maps = { ["<CR>"] = function()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    for i, txt in ipairs(lines) do
      if i == line then
        local name = txt:match("%S+%s+%S+%s+(%S+)")
        for j, t in ipairs(themes) do
          if t.name == name then
            pick(j)
            return
          end
        end
      end
    end
  end }
  for i = 1, math.min(9, #themes) do
    maps[tostring(i)] = function()
      pick(i)
    end
  end

  cmd.scratch("theme", lines, "bpack-themes", { maps = maps })
end

--- `:Bpack theme [nombre|list]`
function M.cmd_theme(args)
  args = vim.trim(args or "")
  if args == "" then
    return picker()
  end
  if args == "list" then
    local lines = {}
    for _, t in ipairs(M.available()) do
      lines[#lines + 1] = ("  %-28s %s"):format(t.name, t.origin)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("  actual: %s · por defecto: %s"):format(tostring(M.current()), M.default)
    return cmd.scratch("theme · list", lines, "bpack-themes")
  end
  if not M.exists(args) then
    local names = vim.tbl_map(function(t)
      return t.name
    end, M.available())
    util.notify(("'Bpack theme %s' no existe. Disponibles: %s"):format(args, table.concat(names, ", ")))
    return
  end
  M.set(args)
end

function M.setup()
  cmd.register("theme", M.cmd_theme, "Cambiar y recordar el tema")

  -- El tema va antes que nada lo demás: un highlight roto se nota en cualquier
  -- UI que monte después.
  local name = M.preferred()
  if not M.apply(name) then
    util.log("el tema guardado (%s) no se pudo aplicar, cae a %s", name, M.default)
    M.apply(M.default)
  end

  return true
end

return M
