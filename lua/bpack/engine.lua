-- El motor: todo lo que habla con `vim.pack`.
--
-- `vim.pack` se ocupa de clonar, de los locks y de `:packadd`. Nosotros somos
-- el specs, los hooks de carga y los comandos. Este archivo es el único lugar
-- que llama a `vim.pack`: si aparece un `vim.pack.add` en otro lado, es un bug.
--
-- La regla de oro del gestor vive acá: nunca se escribe dentro del pack dir.
-- `vim.pack` es su único dueño y llama `error()` si encuentra algo que no sea
-- un clon válido, lo que baja Neovim entero. Por eso ni el lock ni los hooks
-- ni los logs se guardan adentro.

local cmd = require("bpack.cmd")
local util = require("bpack.util")

local M = {}

--- Eventos de `User` que dispara bpack. `VeryLazy` es el que espera el resto de
--- la config; se emite una vez, al final del arranque.
M.lazy_event = "VeryLazy"

--- Nombre del directorio de un plugin, tal como lo va a llamar `vim.pack`.
---
--- `vim.pack` saca el nombre del último segmento del repo. Hay que calcularlo
--- igual para poder cruzar el spec con lo instalado, y hacerlo con la misma
--- regla: si acá se calculara distinto, `:Bpack del` no encontraría nunca nada.
--- @param src string
--- @return string
function M.name_of(src)
  local tail = src:gsub("/+$", ""):match("([^/]+)$") or src
  return (tail:gsub("%.git$", ""))
end

--- El pack dir. Nunca hardcodeado.
---
--- Sale del mismo cálculo que hace `vim.pack` en `get_plug_dir()`, que es una
--- función plana a `stdpath('data')/site/pack/core/opt`. No se lo pregunta a
--- `vim.pack.get` a propósito: `get` dispara `lock_read`, que abre un buffer de
--- confirmación cuando el lock y el disco no coinciden. Con esta ruta
--- aritmética, `:Bpack list` no puede abrir una ventana de decisión ni tocar
--- nada, que es lo que se le pidió.
--- @return string
function M.pack_dir()
  return vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")
end

--- El lockfile. Es el mismo archivo que usa `vim.pack`.
---
--- Ojo con la ruta: `vim.pack` lo pone en `stdpath('config')`, no junto al spec.
--- Instalado, `stdpath('config')` es la raíz del repo, así que el lock se
-- versiona solo. Durante el desarrollo, corriendo `nvim -u ./init.lua` desde
--- el repo, el lock cae en el `~/.config/nvim` de la máquina — fuera del repo.
--- Por eso los tests corren con `XDG_CONFIG_HOME` y `XDG_DATA_HOME` apuntando a
--- un directorio limpio: es la única forma de no tocar la config instalada.
--- @return string
function M.lock_path()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "nvim-pack-lock.json")
end

--- Lee el spec.
--- @return {plugins: string[], config: table<string, fun()>, lazy: table<string, string>}
function M.spec()
  return require("bpack.spec")
end

--- Los plugins declarados, como lista de `{ src, name }`.
--- @return {src: string, name: string}[]
function M.declared()
  local out = {}
  for _, src in ipairs(M.spec().plugins) do
    out[#out + 1] = { src = src, name = M.name_of(src) }
  end
  return out
end

--- Lo que dice el lockfile, leído directo.
---
--- No usa `vim.pack.get` a propósito. `get` llama a `lock_read`, que si
--- detecta que el lock y el disco no coinciden abre un buffer de confirmación
--- para preguntar qué hacer. Eso está bien en `:Bpack sync`, donde la pregunta
--- tiene sentido, pero `:Bpack list` no debería poder mutar nada ni abrir una
--- ventana de decisión: listar tiene que ser siempre inocuo.
--- @return {name: string, src: string, version: string|nil, rev: string|nil, path: string}[]
function M.locked()
  local path = M.lock_path()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end
  local raw = table.concat(vim.fn.readfile(path), "\n")
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or type(decoded) ~= "table" or type(decoded.plugins) ~= "table" then
    util.log("lockfile ilegible: %s", tostring(decoded))
    return {}
  end

  local plug_dir = M.pack_dir()
  local out = {}
  for name, data in pairs(decoded.plugins) do
    out[#out + 1] = {
      name = name,
      src = data.src,
      version = data.version,
      rev = data.rev,
      path = vim.fs.joinpath(plug_dir, name),
    }
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

--- El estado completo: declarado en el spec, y en el lock.
---
--- De ahí sale la respuesta a las dos preguntas que el gestor tiene que poder
--- contestar siempre: qué falta instalar, y qué está en el disco sin estar
--- declarado.
--- @return {name: string, src: string, in_spec: boolean, in_lock: boolean, rev: string|nil, path: string|nil}[]
function M.status()
  local out, by_name = {}, {}
  for _, d in ipairs(M.declared()) do
    local row = { name = d.name, src = d.src, in_spec = true, in_lock = false }
    by_name[d.name] = row
    out[#out + 1] = row
  end
  for _, l in ipairs(M.locked()) do
    local row = by_name[l.name]
    if row then
      row.in_lock = true
      row.rev = l.rev
      row.path = l.path
      if row.src ~= l.src then
        row.src_changed = true
        row.locked_src = l.src
      end
    else
      out[#out + 1] = {
        name = l.name,
        src = l.src,
        in_spec = false,
        in_lock = true,
        rev = l.rev,
        path = l.path,
        orphan = true,
      }
    end
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

--- Corre el `config` de un plugin, una vez.
--- @param name string
--- @return boolean ok
function M.load_config(name)
  local spec = M.spec()
  local fn = spec.config[name]
  if not fn then
    return true
  end
  return util.protect("config:" .. name, fn)
end

--- Carga diferida. Un autocmd `User` de un solo disparo por plugin.
--- @param plug {spec: table, path: string}
function M.setup_lazy(plug)
  local name = plug.spec.name
  local event = M.spec().lazy[name]
  if not event then
    return
  end
  vim.api.nvim_create_autocmd("User", {
    pattern = event,
    once = true,
    group = vim.api.nvim_create_augroup("BpackLazy", { clear = true }),
    desc = ("bpack: carga diferida de %s"):format(name),
    callback = function()
      M.load_config(name)
    end,
  })
end

--- Registra los plugins del spec.
---
--- Idempotente: si ya están en el disco, `vim.pack` no clona nada y sólo hace
--- `:packadd`. Por eso esto va en cada arranque.
--- @param names? string[] sólo estos. Por defecto, todos los del spec.
--- @return {ok: boolean, added: string[], failed: {name: string, err: string}[]}
function M.add(names)
  local want = names and vim.deepcopy(names) or vim.tbl_map(function(d)
    return d.src
  end, M.declared())

  if #want == 0 then
    return { ok = true, added = {}, failed = {} }
  end

  local result = { ok = true, added = {}, failed = {} }

  -- `load` corre en el callback de `vim.pack`, con los datos del plugin ya
  -- resueltos. Para los eager alcanza con el default; para los lazy hay que
  -- interceptar, porque el default hace `:packadd` y con eso el plugin queda
  -- cargado desde el arranque.
  local load = function(plug)
    if plug.spec.name and M.spec().lazy[plug.spec.name] then
      M.setup_lazy(plug)
      util.log("carga diferida: %s (%s)", plug.spec.name, plug.path)
      return
    end
    -- `:packadd!`, con "!" a propósito. Bpack llama a `vim.pack.add` desde
    -- `init.lua`, o sea durante el arranque, y para ese caso la ayuda dice
    -- que la forma correcta es `:packadd!`: la "!" evita que el plugin cargue
    -- si se arrancó con `--noplugin`. Sin la "!", `:packadd` sourcea los
    -- `plugin/` del paquete y después el pase de arranque los sourcea otra vez:
    -- el plugin corre dos veces. Medido: 2 con `:packadd`, 1 con `:packadd!`.
    --
    -- El escape de espacios es el mismo que hace `vim.pack`: `:packadd` no los
    -- maneja bien.
    vim.cmd.packadd({ vim.fn.escape(plug.spec.name, " "), bang = true, magic = { file = false } })
    M.load_config(plug.spec.name)
  end

  local ok, err = pcall(vim.pack.add, want, { load = load, confirm = false })
  if not ok then
    util.log("vim.pack.add fallo: %s", tostring(err))
    util.notify("vim.pack falló: " .. tostring(err), vim.log.levels.ERROR)
    result.ok = false
    result.failed[#result.failed + 1] = { name = "?", err = tostring(err) }
    return result
  end

  for _, d in ipairs(M.declared()) do
    if vim.tbl_contains(want, d.src) then
      result.added[#result.added + 1] = d.name
    end
  end

  return result
end

-- ── Subcomandos ───────────────────────────────────────────────────────────

--- Ruta del archivo del spec.
---
--- Se busca en el rtp, no en `stdpath('config')`. En la instalación los dos
--- coinciden; en desarrollo —`nvim -u ./init.lua` desde el repo— el spec está
--- en el repo y `stdpath('config')` apunta a otro lado. Escribir en la ruta
--- equivocada deja el spec viejo en disco y el `:Bpack add` parece no hacer
--- nada.
---
--- Tampoco sirve `package.searchpath`: `init.lua` antepone el repo al
--- *runtimepath*, y Lua resuelve el `require` por ahí, no por `package.path`.
--- Recorrer el rtp es lo que refleja de verdad de dónde salió el módulo.
--- @return string
function M.spec_path()
  for _, dir in ipairs(vim.api.nvim_list_runtime_paths()) do
    local candidate = vim.fs.joinpath(dir, "lua", "bpack", "spec.lua")
    if vim.fn.filereadable(candidate) == 1 then
      return candidate
    end
  end
  return vim.fs.joinpath(vim.fn.stdpath("config"), "lua", "bpack", "spec.lua")
end

--- Escribe la lista `plugins` del spec a disco.
---
--- Reemplaza todo lo que hay entre los marcadores `bpack:plugins`. Antes de
--- dejar el resultado lo *evalúa*, y no sólo lo compila: un `loadstring` alcanza
--- para detectar sintaxis rota, pero no detecta un string suelto fuera de la
--- lista, que es Lua perfectamente válido y deja el spec inútil. Un `:Bpack add`
--- que rompe el spec deja al usuario sin config en el próximo arranque, y eso
--- no se arregla con un mensaje de error.
--- @return boolean ok
function M.write_spec()
  local path = M.spec_path()
  if vim.fn.filereadable(path) == 0 then
    util.log("spec.lua no existe en %s", path)
    util.notify("no se encontró spec.lua en " .. path, vim.log.levels.ERROR)
    return false
  end

  local original = table.concat(vim.fn.readfile(path), "\n")
  local lines = vim.split(original, "\n", { plain = true })

  local open_at, close_at
  for i, line in ipairs(lines) do
    if open_at == nil and line:find(">>> bpack:plugins", 1, true) then
      open_at = i
    elseif open_at and line:find("<<< bpack:plugins", 1, true) then
      close_at = i
      break
    end
  end
  if not open_at or not close_at then
    util.log("spec.lua sin marcadores bpack:plugins")
    util.notify("spec.lua no tiene los marcadores bpack:plugins — no se toca", vim.log.levels.ERROR)
    return false
  end

  -- Sin plugins se deja la forma de una línea, que es como está el archivo en
  -- el repo: un `plugins = {` y un `},` solos ensucian el diff de un `del` que
  -- dejó la lista vacía.
  local body
  if #M.spec().plugins == 0 then
    body = { "  plugins = {}," }
  else
    body = { "  plugins = {" }
    for _, src in ipairs(M.spec().plugins) do
      body[#body + 1] = ('    "%s",'):format(src)
    end
    body[#body + 1] = "  },"
  end

  local out = {}
  vim.list_extend(out, vim.list_slice(lines, 1, open_at))
  vim.list_extend(out, body)
  vim.list_extend(out, vim.list_slice(lines, close_at))
  local rendered = table.concat(out, "\n")

  if rendered == original then
    return true
  end

  -- Validar de verdad: tiene que compilar Y devolver la lista que pedimos.
  local chunk, err = loadstring(rendered, "@" .. path)
  if not chunk then
    util.log("el spec generado no compila, se deja el original: %s", tostring(err))
    util.notify("el spec generado no compilaba; no se escribió nada", vim.log.levels.ERROR)
    return false
  end

  local ok_eval, result = pcall(chunk)
  local got = ok_eval and type(result) == "table" and result.plugins or nil
  if type(got) ~= "table" or not vim.deep_equal(got, M.spec().plugins) then
    util.log("el spec generado no devuelve la lista esperada: %s", vim.inspect(got))
    util.notify("el spec generado no devolvió la lista esperada; no se escribió nada", vim.log.levels.ERROR)
    return false
  end

  local fd = io.open(path, "w")
  if not fd then
    util.log("no se pudo abrir %s para escribir", path)
    return false
  end
  fd:write(rendered)
  fd:close()
  util.log("spec escrito: %s (%d plugin/s)", path, #M.spec().plugins)
  return true
end

--- `:Bpack sync` — spec <-> disco <-> lock. Idempotente.
function M.cmd_sync()
  local before = M.status()
  local missing = vim.tbl_filter(function(r)
    return r.in_spec and not r.in_lock
  end, before)
  local orphans = vim.tbl_filter(function(r)
    return r.orphan
  end, before)

  if #missing == 0 then
    util.notify(("spec y disco al día (%d plugin/s)"):format(#before), vim.log.levels.INFO)
  else
    local names = vim.tbl_map(function(r)
      return r.name
    end, missing)
    util.notify(("instalando %d plugin(s): %s"):format(#missing, table.concat(names, ", ")))
  end

  local res = M.add()
  if not res.ok then
    return
  end

  if #missing > 0 then
    util.notify(("instalados: %s"):format(table.concat(res.added, ", ")))
  end

  if #orphans > 0 then
    -- No se borran solos: un sync que borra el trabajo del usuario es un sync
    -- que alguien va a odiar. Se avisa y se deja que elija con `:Bpack del`.
    util.notify(
      ("%d plugin(s) en el disco sin estar en el spec: %s. ':Bpack del <nombre>' los borra.")
        :format(#orphans, table.concat(vim.tbl_map(function(r)
          return r.name
        end, orphans), ", ")),
      vim.log.levels.WARN
    )
  end
end

--- `:Bpack add owner/repo` — clona y agrega al spec.
function M.cmd_add(args)
  local src = vim.trim(args)
  if src == "" then
    return util.notify("uso: :Bpack add owner/repo", vim.log.levels.ERROR)
  end

  local name = M.name_of(src)
  if not src:match("^%S+/.+") then
    return util.notify(("'%s' no parece un repo. Formato: owner/repo"):format(src), vim.log.levels.ERROR)
  end

  local spec = M.spec()
  for _, d in ipairs(M.declared()) do
    if d.name == name then
      return util.notify(("'%s' ya está en el spec"):format(name), vim.log.levels.WARN)
    end
  end

  local res = M.add({ src })
  if not res.ok then
    return
  end

  table.insert(spec.plugins, src)
  if not M.write_spec() then
    -- Sin el spec en disco, el próximo arranque no lo reinstala. Se saca de la
    -- lista en memoria para no quedar en un estado que nadie más ve.
    table.remove(spec.plugins)
    return
  end
  util.notify(("agregado %s. Si querés config, ponela en spec.config['%s']"):format(src, name))
end

--- Saca un nombre de la lista del spec en memoria.
--- @param name string
--- @return boolean estaba
local function remove_from_spec(name)
  for i, src in ipairs(M.spec().plugins) do
    -- La lista son strings, no tablas: el nombre sale de la fuente, igual que
    -- en `declared`. Comparar `src.name` no matchea nunca y el `:Bpack del`
    -- borra el disco pero deja el spec lleno, así que el próximo arranque
    -- reinstala el plugin que el usuario acaba de borrar.
    if M.name_of(src) == name then
      table.remove(M.spec().plugins, i)
      return true
    end
  end
  return false
end

--- `:Bpack del name` — borra del disco y saca del spec.
---
--- Borra el directorio de verdad (`vim.pack.del` hace `rm -rf` del path) y saca
--- la entrada del spec, para que no vuelva a aparecer en `:Bpack list`.
function M.cmd_del(args)
  local name = vim.trim(args)
  if name == "" then
    return util.notify("uso: :Bpack del <nombre>", vim.log.levels.ERROR)
  end

  local installed = false
  for _, l in ipairs(M.locked()) do
    if l.name == name then
      installed = true
    end
  end

  if not installed then
    if not remove_from_spec(name) then
      return util.notify(("'%s' no está instalado ni en el spec"):format(name), vim.log.levels.WARN)
    end
    M.write_spec()
    return util.notify(("sacado del spec: %s (no estaba instalado)"):format(name))
  end

  local ok, err = pcall(vim.pack.del, { name }, { force = true })
  if not ok then
    util.log("vim.pack.del fallo: %s", tostring(err))
    return util.notify("no se pudo borrar " .. name .. ": " .. tostring(err), vim.log.levels.ERROR)
  end

  if remove_from_spec(name) then
    M.write_spec()
  end
  util.notify(("borrado: %s"):format(name))
end

--- `:Bpack update [name]!` — el `!` aplica sin preguntar.
---
--- Sin `!` se abre el buffer de confirmación nativo de `vim.pack`, que ya
--- muestra el changelog. No lo reemplazamos: hace mejor ese trabajo del que
--- haríamos nosotros.
function M.cmd_update(args)
  -- El dispatcher deja el `!` adelante (`update! telescope`), no al final.
  local bang = args:sub(1, 1) == "!"
  local rest = vim.trim(bang and args:sub(2) or args)

  local names
  if rest ~= "" then
    names = { rest }
    local known = false
    for _, r in ipairs(M.status()) do
      if r.name == rest then
        known = true
      end
    end
    if not known then
      return util.notify(("'%s' no está instalado. ':Bpack list' para ver."):format(rest), vim.log.levels.WARN)
    end
  end

  local ok, err = pcall(vim.pack.update, names, { force = bang })
  if not ok then
    util.log("vim.pack.update fallo: %s", tostring(err))
    return util.notify("update falló: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- `:Bpack list` — qué está declarado, qué está en el disco, y qué sobra.
function M.cmd_list()
  local rows = M.status()
  if #rows == 0 then
    return util.notify("no hay plugins. ':Bpack add owner/repo'")
  end

  local lines = {}
  for _, r in ipairs(rows) do
    local mark, note
    if r.orphan then
      mark, note = "!", "en el disco, no en el spec"
    elseif r.src_changed then
      mark, note = "?", "el spec cambió de repo"
    else
      mark, note = "✓", "instalado"
    end
    lines[#lines + 1] = ("  %s %-32s %-10s %s"):format(
      mark,
      r.name,
      r.rev and r.rev:sub(1, 8) or "-",
      r.src
    )
    if r.orphan or r.src_changed then
      lines[#lines + 1] = ("      %s"):format(note)
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = ("  %d en el spec, %d en el disco"):format(
    #vim.tbl_filter(function(r)
      return r.in_spec
    end, rows),
    #vim.tbl_filter(function(r)
      return r.in_lock
    end, rows)
  )
  lines[#lines + 1] = "  ✓ al día   ! huérfano (borralo con :Bpack del)   ? el spec cambió de repo"

  cmd.scratch("list", lines, "bpack-list")
end

--- `:Bpack log name [n]` — los últimos commits de un plugin.
function M.cmd_log(args)
  local name, n = args:match("^(%S+)%s*(%d*)$")
  if not name then
    return util.notify("uso: :Bpack log <nombre> [n]", vim.log.levels.ERROR)
  end
  n = tonumber(n) or 10

  local path
  for _, r in ipairs(M.status()) do
    if r.name == name then
      path = r.path
    end
  end
  if not path or not path or vim.fn.isdirectory(path) == 0 then
    return util.notify(("'%s' no está instalado"):format(name), vim.log.levels.WARN)
  end

  -- `on_exit` recibe un único `vim.SystemCompleted`: el código y el stdout van
  -- adentro de él, no en argumentos sueltos. Con `text = true` el stdout ya
  -- viene como string.
  vim.system({ "git", "-C", path, "log", "--oneline", "--decorate", "-n", tostring(n) }, {
    text = true,
  }, function(result)
    -- El callback corre en fast-event context: ahí no se puede tocar la API de
    -- Neovim. `notify` y `scratch` se llaman de vuelta en el loop principal, o
    -- tiran "must not be called in a fast event context".
    vim.schedule(function()
      if not result or result.code ~= 0 then
        return util.notify(
          ("git log falló en %s (código %s)"):format(name, tostring(result and result.code)),
          vim.log.levels.ERROR
        )
      end
      local lines = vim.split(result.stdout, "\n", { trimempty = true })
      cmd.scratch(("log · " .. name), lines, "bpack-log")
    end)
  end)
end

function M.setup()
  cmd.register("sync", M.cmd_sync, "Spec <-> disco <-> lock, idempotente")
  cmd.register("add", M.cmd_add, "Clonar un repo y sumarlo al spec")
  cmd.register("del", M.cmd_del, "Borrar un plugin del disco y del spec")
  cmd.register("update", M.cmd_update, "Actualizar (con ! aplica sin preguntar)")
  cmd.register("list", M.cmd_list, "Qué está declarado y qué está en el disco")
  cmd.register("log", M.cmd_log, "Últimos commits de un plugin")

  return M.add().ok
end

return M
