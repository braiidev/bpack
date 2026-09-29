-- Comandos del gestor: `:Bpack <subcomando>`.
--
-- Todos pasan por acá. El subcomando se separa del resto en el primer espacio,
-- así que `:Bpack update nvim-cmp` es `update` con el argumento `nvim-cmp`.

local M = {}

--- Subcomandos disponibles. Es un registro, no una lista fija: cada módulo
--- publica el suyo desde su `setup()` con `M.register`. Así agregar un
--- subcomando es agregar un archivo, no editar este.
--- @type table<string, fun(args: string)>
M.subs = {}

--- Descripción de cada subcomando, para el autocompletado.
--- @type table<string, string>
M.descriptions = {}

--- Abre un buffer scratch con líneas. Base de `:Bpack keys` y de lo que venga.
---
--- `opts.maps` son atajos buffer-locales: `{ ["<CR>"] = fun() end }`. Los usa
--- el selector de temas para que se pueda elegir con un número.
--- @param title string
--- @param lines string[]
--- @param ft string
--- @param opts? { maps?: table<string, string|fun()>, winopts?: table }
--- @return integer bufnr
function M.scratch(title, lines, ft, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "bpack://" .. title)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = ft

  local width = math.min(96, vim.o.columns - 6)
  local height = math.min(#lines + 1, vim.o.lines - 4)
  local win = vim.api.nvim_open_win(buf, true, vim.tbl_extend("force", {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " bpack · " .. title .. " ",
    title_pos = "center",
  }, opts.winopts or {}))

  vim.wo[win].wrap = false
  vim.wo[win].conceallevel = 2
  vim.wo[win].concealcursor = "nvic"
  vim.keymap.set("n", "q", "<cmd>close<scr>", { buffer = buf, nowait = true, silent = true })
  for lhs, rhs in pairs(opts.maps or {}) do
    vim.keymap.set("n", lhs, rhs, { buffer = buf, nowait = true, silent = true })
  end
  return buf
end

--- Los modos que se leen para listar atajos.
local modes = { "n", "v", "x", "s", "o", "i", "c", "t" }

--- Nombre legible de cada modo, para la columna del listado.
local mode_names = {
  n = "normal",
  v = "visual",
  x = "select",
  s = "select",
  o = "operator",
  i = "insert",
  c = "cmdline",
  t = "terminal",
}

--- El modo que realmente declara el atajo.
---
--- `nvim_get_keymap` devuelve `mode = ""` para el modo normal, y un atajo de
--- select (`x`) aparece también dentro de la consulta de visual (`v`) porque
--- select es un subconjunto de visual. Sin canonicalizar, cada atajo de `x`
--- salía listado dos veces: como visual y como select.
--- @param km table
--- @return string
local function canonical_mode(km)
  return km.mode == "" and "n" or km.mode
end

--- `:Bpack keys [patrón]`
---
--- Lee el estado vivo del editor, no el índice: por eso aparecen también los
--- atajos que las features registran en su `setup()`. Sólo entra lo que lleva
--- el prefijo de bpack en la `desc`, porque los atajos por defecto de Neovim
--- también traen `desc` y si no se filtran ensucian la lista.
function M.keys(args)
  local keymap = require("bpack.keymap")
  local index = require("bpack.keys")
  local pattern = args ~= "" and args or nil

  -- El grupo sale del índice, para los atajos de núcleo; lo que no esté
  -- declarado va a "features". La clave pasa por `canonical_lhs` de los dos
  -- lados, porque el índice y `get_keymap` no escriben el mismo `lhs`.
  local groups = {}
  for _, k in ipairs(keymap.declared()) do
    local lhs = keymap.canonical_lhs(k.lhs)
    for _, m in ipairs(type(k.mode) == "table" and k.mode or { k.mode }) do
      groups[m .. " " .. lhs] = k.group
    end
  end

  local rows = {}
  for _, mode in ipairs(modes) do
    for _, km in ipairs(vim.api.nvim_get_keymap(mode)) do
      if type(km.desc) == "string" and km.desc:sub(1, #keymap.prefix) == keymap.prefix
        and canonical_mode(km) == mode
      then
        -- Se muestra el `lhs` del editor, con el leader devuelto a `<leader>`
        -- y `<`/`>` desescapados, que es como está escrito en el índice.
        local lhs = km.lhs
        if index.leader and index.leader ~= "" then
          lhs = lhs:gsub(vim.pesc(index.leader), "<leader>")
        end
        lhs = lhs:gsub("<lt>", "<"):gsub("<gt>", ">")
        rows[#rows + 1] = {
          mode = mode,
          mode_name = mode_names[mode] or mode,
          lhs = lhs,
          desc = km.desc:sub(#keymap.prefix + 1),
          group = groups[mode .. " " .. keymap.canonical_lhs(km.lhs)] or "features",
        }
      end
    end
  end

  if pattern then
    local filtered = {}
    for _, r in ipairs(rows) do
      -- Se busca también en el grupo: `:Bpack keys colores` es más natural que
      -- acordarse del nombre de un atajo.
      if r.lhs:lower():find(pattern:lower(), 1, true)
        or r.desc:lower():find(pattern:lower(), 1, true)
        or r.group:lower():find(pattern:lower(), 1, true)
      then
        filtered[#filtered + 1] = r
      end
    end
    rows = filtered
  end

  if #rows == 0 then
    require("bpack.util").notify(pattern and ("nada coincide con '" .. pattern .. "'") or "no hay atajos de bpack")
    return
  end

  table.sort(rows, function(a, b)
    if a.group ~= b.group then
      return a.group < b.group
    end
    if a.lhs ~= b.lhs then
      return a.lhs < b.lhs
    end
    return a.mode < b.mode
  end)

  local lines = {}
  local last_group = nil
  for _, r in ipairs(rows) do
    if r.group ~= last_group then
      if last_group ~= nil then
        lines[#lines + 1] = ""
      end
      lines[#lines + 1] = "── " .. r.group .. " ──"
      last_group = r.group
    end
    lines[#lines + 1] = ("  %-11s %-28s %s"):format(r.mode_name, r.lhs, r.desc)
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = ("  %d atajo(s) de bpack. Leader: %q"):format(#rows, index.leader)

  M.scratch("keys", lines, "bpack-keys")
end

--- Publica un subcomando. Lo llaman las features en su `setup()`.
--- @param name string
--- @param fn fun(args: string)
--- @param desc string para el autocompletado
function M.register(name, fn, desc)
  M.subs[name] = fn
  M.descriptions[name] = desc
  return fn
end

--- La lista de subcomandos con su descripción, para el mensaje de error.
--- @return string[]
local function subcommand_list()
  local names = vim.tbl_keys(M.subs)
  table.sort(names)
  return vim.tbl_map(function(name)
    return M.descriptions[name] and (name .. " — " .. M.descriptions[name]) or name
  end, names)
end

function M.setup()
  vim.api.nvim_create_user_command("Bpack", function(cmd)
    local arg = cmd.args or ""
    local sub, rest = arg:match("^(%S+)%s*(.*)$")

    -- El `!` va siempre pegado al subcomando, como en `:w!` y `:q!`:
    -- `:Bpack update! telescope`, `:Bpack selfupdate!`. Se separa acá y se le
    -- pasa al handler como primer caracter de `rest`, para que los tres
    -- comandos que lo usan lo entiendan igual.
    --
    -- Sin esto `:Bpack selfupdate!` no resolvia: `match` se llevaba el `!` como
    -- parte del nombre, `M.subs["selfupdate!"]` era nil, y el comando rechazaba
    -- una sintaxis que el help anunciaba.
    if sub and sub:sub(-1) == "!" then
      sub = sub:sub(1, -2)
      rest = rest ~= "" and ("! " .. rest) or "!"
    end

    if not sub or M.subs[sub] == nil then
      require("bpack.util").notify(
        ("'Bpack %s' no existe. Disponibles: %s"):format(
          tostring(sub),
          table.concat(subcommand_list(), "  ·  ")
        )
      )
      return
    end
    M.subs[sub](rest)
  end, {
    nargs = "*",
    -- `force` para que volver a llamar a `setup()` no reviente: reload y
    -- self-update rehacen el arranque sobre el Neovim que ya está corriendo.
    force = true,
    desc = "Gestor de plugins, atajos y temas de bpack",
    complete = function(lead)
      local names = vim.tbl_keys(M.subs)
      table.sort(names)
      return vim.tbl_filter(function(name)
        return name:find(lead, 1, true) == 1
      end, names)
    end,
  })

  M.register("keys", M.keys, "Atajos, agrupados")

  return true
end

return M
