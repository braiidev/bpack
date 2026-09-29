-- Motor de atajos: valida el índice de `bpack.keys` y lo registra.
--
-- El índice es la única fuente de los atajos de núcleo, así que el registro no
-- se escribe a mano en dos lugares. `:Bpack keys` no lee el índice sino el
-- estado vivo del editor, de modo que los atajos que agregan las features
-- aparecen en la misma lista sin pasar por acá.
--
-- La `desc` es obligatoria: sin ella un atajo es invisible para el usuario y
-- para `:Bpack keys`, que es exactamente el problema que arrastraba la lista
-- de atajos a mano de la config anterior.

local M = {}

--- Prefijo de las descripciones. Sin esto, `:Bpack keys` no puede distinguir
--- los atajos nuestros de los que Neovim trae por defecto: en visual, `*`, `#`,
--- `&` y compañía vienen con `desc` posto (`:help v_star-default`) y se colaban
--- en la lista como si fueran del gestor.
M.prefix = "bpack: "

--- Atajos inválidos encontrados en el arranque.
--- @type string[]
M.invalid = {}

--- Registra un atajo fuera del índice. Lo usan las features.
---
--- No escribe en `bpack.keys`: ese archivo es la fuente versionada de los
--- atajos de núcleo, y lo que agrega un plugin no va en el repo. Se prefija la
--- `desc` para que el atajo sea atribuible a bpack.
--- @param mode string|string[]
--- @param lhs string
--- @param rhs string|fun()
--- @param desc string texto sin el prefijo
--- @param opts? table
function M.set(mode, lhs, rhs, desc, opts)
  local full = desc:sub(1, #M.prefix) == M.prefix and desc or (M.prefix .. desc)
  return vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", {
    desc = full,
    silent = true,
    noremap = true,
  }, opts or {}))
end

--- Valida una entrada del índice. Devuelve el motivo si no sirve.
--- @param i integer posición en el índice, para el mensaje
--- @param entry any
--- @return string|nil err
local function validate(i, entry)
  if type(entry) ~= "table" then
    return "no es una tabla"
  end
  local mode, lhs, rhs, desc = entry[1], entry[2], entry[3], entry[4]
  if type(mode) == "table" then
    for _, m in ipairs(mode) do
      if type(m) ~= "string" then
        return "la lista de modos tiene un valor que no es string"
      end
    end
  elseif type(mode) ~= "string" or mode == "" then
    return "modo inválido"
  end
  if type(lhs) ~= "string" or lhs == "" then
    return "lhs inválido"
  end
  if type(rhs) ~= "string" and type(rhs) ~= "function" then
    return "rhs inválido"
  end
  if type(desc) ~= "string" or desc == "" then
    return "sin desc"
  end
  return nil
end

function M.setup()
  M.invalid = {}

  local index = require("bpack.keys")

  -- El leader se define antes de registrar nada: los atajos que usan
  -- `<leader>` se resuelven contra `mapleader` en el momento del registro.
  vim.g.mapleader = index.leader or " "
  vim.g.maplocalleader = index.localleader or " "

  -- Detecta duplicados antes de mappear, porque el segundo pisa al primero en
  -- silencio y el síntoma aparece mucho después, en otra sesión.
  local seen = {}

  for i, entry in ipairs(index.entries) do
    local err = validate(i, entry)
    if err then
      M.invalid[#M.invalid + 1] = ("#%d %s: %s"):format(
        i,
        type(entry) == "table" and tostring(entry[2]) or "<?>",
        err
      )
    else
      local mode, lhs = entry[1], entry[2]
      local modes = type(mode) == "table" and mode or { mode }
      for _, m in ipairs(modes) do
        local id = m .. " " .. lhs
        if seen[id] then
          M.invalid[#M.invalid + 1] = ("#%d %s en %s: ya estaba en #%d"):format(i, lhs, m, seen[id])
        end
        seen[id] = i
      end
      M.set(entry[1], entry[2], entry[3], entry[4], { noremap = true })
    end
  end

  if #M.invalid > 0 then
    require("bpack.util").log("keys: %d entrada(s) inválida(s)\n%s", #M.invalid, table.concat(M.invalid, "\n"))
  end

  return #M.invalid == 0
end

--- Deja un `lhs` comparable entre el índice y `nvim_get_keymap`.
---
--- Los dos lados escriben lo mismo pero no se devuelven igual: el índice dice
--- `<A-j>` y `get_keymap` devuelve `<M-j>`; el índice dice `s<` y `get_keymap`
--- devuelve `s<lt>`, porque `<` y `>` tienen que ir escapados. Y el leader, que
--- en el índice es `<leader>`, vuelve como un espacio literal.
---
--- Toda comparación de atajos pasa por acá, así que el listado y `bpack doctor`
--- comparten la misma regla y no pueden discrepar.
--- @param lhs string
--- @return string
function M.canonical_lhs(lhs)
  local s = lhs:gsub("<[sS]pace>", (require("bpack.keys").leader or " "))
  s = s:gsub("<[lL]eader>", (require("bpack.keys").leader or " "))
  s = s:gsub("<A%-(%a)", "<M-%1")
  s = s:gsub("<lt>", "<")
  s = s:gsub("<gt>", ">")
  return s:lower()
end

--- Atajos declarados en el índice, tal como están escritos.
---
--- El `lhs` conserva `<leader>` sin expandir, que es la forma en que coincide
--- con lo que devuelve `nvim_get_keymap` una vez normalizado. Los usa
--- `bpack doctor` para verificar que exista lo que se declaró.
--- @return {mode: string|string[], lhs: string, rhs: string|fun(), desc: string, group: string|nil}[]
function M.declared()
  local out = {}
  for _, entry in ipairs(require("bpack.keys").entries) do
    out[#out + 1] = {
      mode = entry[1],
      lhs = entry[2] or "",
      rhs = entry[3],
      desc = entry[4],
      group = entry[5],
    }
  end
  return out
end

return M
