-- Estado persistente de bpack: lo que es de la máquina y no del repo.
--
-- Va a `stdpath('state')/bpack/state.json`. El tema elegido, por ejemplo, es una
-- preferencia de esta instalación: si viviera en el repo, cambiar de tema sería
-- un commit, y dos máquinas con el mismo repo no podrían tener temas distintos.
--
-- NUNCA dentro del pack dir. Ver la decisión 3 del `PLAN.md`: escribir ahí es lo
-- que terminó matando el arranque de la config anterior.

local util = require("bpack.util")

local M = {}

--- Caché de la sesión. Se lee una vez y se mantiene.
--- @type table<string, any>|nil
local cache = nil

--- Ruta del archivo de estado.
--- @return string
function M.path()
  return vim.fs.joinpath(util.state_dir(), "state.json")
end

--- Estado completo, leído del disco la primera vez.
--- @return table<string, any>
function M.read()
  if cache then
    return cache
  end
  local path = M.path()
  if vim.fn.filereadable(path) == 0 then
    cache = {}
    return cache
  end
  local raw = table.concat(vim.fn.readfile(path), "\n")
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" then
    -- Un estado corrupto no vale la pena romper el arranque por él: se avisa,
    -- se deja como estaba y se sigue con el default.
    util.log("state.json ilegible, se arranca con defaults: %s", tostring(decoded))
    util.notify("state.json ilegible — se usan los valores por defecto", vim.log.levels.WARN)
    cache = {}
    return cache
  end
  cache = decoded
  return cache
end

--- Lee una clave.
--- @param key string
--- @param default? any
--- @return any
function M.get(key, default)
  local value = M.read()[key]
  if value == nil then
    return default
  end
  return value
end

--- Escribe a disco. Atómico: primero un temporal, después el rename. Si
--- Neovim se muere a mitad de escritura queda el `state.json` viejo, no uno
--- truncado que no se puede leer.
--- @return boolean ok
function M.write()
  local path = M.path()
  local tmp = path .. ".tmp"
  local json = vim.json.encode(cache or {})
  local ok, err = pcall(function()
    vim.fn.writefile(vim.split(json, "\n", { plain = true }), tmp)
    vim.fn.rename(tmp, path)
  end)
  if not ok then
    util.log("no se pudo escribir state.json: %s", tostring(err))
    util.notify("no se pudo guardar el estado: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Cambia una clave y persiste. Sólo llama a `write` si el valor cambió, para
--- no tocar el disco en cada arranque.
--- @param key string
--- @param value any
--- @return boolean ok
function M.set(key, value)
  local state = M.read()
  if vim.deep_equal(state[key], value) then
    return true
  end
  state[key] = value
  return M.write()
end

--- Borra una clave y persiste.
--- @param key string
--- @return boolean ok
function M.unset(key)
  local state = M.read()
  if state[key] == nil then
    return true
  end
  state[key] = nil
  return M.write()
end

return M
