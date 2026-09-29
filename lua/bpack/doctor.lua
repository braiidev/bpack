--- Diagnóstico de la config: `:Bpack doctor`.
---
--- Todo lo que hace es **leer**. Ni un `vim.pack.add`, ni un `mkdir`, ni un
--- `:packadd`: si el doctor repara algo, deja de ser un doctor y se vuelve el
--- lugar donde una config rota se rompe un poco más. Para arreglar está
--- `:Bpack sync`, y para borrar `:Bpack del`.
---
--- Es la herramienta que resuelve "¿por qué no me anda esto?" sin tener que
--- leer tres archivos. El caso que la hizo necesaria: la config anterior tenía
--- un archivo suelto dentro del pack dir, que `vim.pack` no tolera y que
--- revienta el arranque entero. Ese tipo de cosa es invisible salvo que alguien
--- mire.
---
--- Las comprobaciones devuelven datos estructurados (`M.run()`) además de
--- dibujarse (`M.cmd_doctor()`), para que `scripts/bpack --doctor` pueda
--- consumirlas sin pasar por una ventana.

local cmd = require("bpack.cmd")
local util = require("bpack.util")

local M = {}

--- @alias bpack.Level '"ok"'|'"info"'|'"warn"'|'"error"'

--- @class bpack.Check
--- @field level bpack.Level
--- @field label string qué se comprobó
--- @field detail string|nil el valor encontrado, o por qué falla

--- El orden de un `require` no es una preferencia: `bpack.engine` llama a
--- `bpack.cmd` y `vim.pack`, así que tiene que estar cargado cuando esto corre.
local engine = require("bpack.engine")

--- La guarda de versión de `bpack/init.lua`, en un solo lugar.
--- @param min table
--- @return boolean
local function at_least(min)
  return vim.version.ge(vim.version(), min)
end

--- @param cmdline string[]
--- @return string|nil la primera línea de stdout, o nil si no se pudo correr
local function first_line(cmdline)
  if vim.fn.executable(cmdline[1]) ~= 1 then
    return nil
  end
  local ok, out = pcall(vim.fn.system, cmdline)
  if not ok or vim.v.shell_error ~= 0 then
    return nil
  end
  return (vim.split(out, "\n", { trimempty = true })[1])
end

--- ¿Se puede escribir acá? No escribe nada: mira los permisos declarados.
--- @param path string
--- @return boolean
local function writable(path)
  if vim.fn.isdirectory(path) == 0 then
    return false
  end
  local perms = vim.fn.getfperm(path)
  -- Sin grupo ni otros: no podemos saber nada, no digamos que no se puede.
  return perms:sub(4) ~= "" or perms:sub(7) ~= ""
end

--- Rutas que bpack necesita poder leer y escribir.
--- @param level bpack.Level
--- @param label string
--- @param path string
--- @param opts? {need_exists?: boolean, need_dir?: boolean}
--- @return bpack.Check
local function check_path(label, path, opts)
  opts = opts or {}
  local exists = vim.fn.filereadable(path) == 1
  if opts.need_dir then
    exists = vim.fn.isdirectory(path) == 1
  end

  if not exists and opts.need_exists then
    return { level = "error", label = label, detail = "no existe: " .. path }
  end
  if not writable(vim.fs.dirname(path)) then
    return { level = "error", label = label, detail = "directorio sin permiso de escritura: " .. vim.fs.dirname(path) }
  end
  return { level = "ok", label = label, detail = path }
end

--- ── Neovim ─────────────────────────────────────────────────────────────────

--- @return bpack.Check[]
local function check_nvim()
  local v = vim.version()
  local detail = ("%d.%d.%d"):format(v.major, v.minor, v.patch)
  if not at_least({ 0, 12, 0 }) then
    return {
      { level = "error", label = "Neovim", detail = detail .. " — se necesita 0.12 o más" },
      { level = "info", label = "  por qué", detail = "el gestor usa vim.pack, que no existe antes de 0.12" },
    }
  end
  return { { level = "ok", label = "Neovim", detail = detail } }
end

--- ── Herramientas externas ──────────────────────────────────────────────────

--- @return bpack.Check[]
local function check_tools()
  local out = {}

  local git = first_line({ "git", "--version" })
  if git then
    out[#out + 1] = { level = "ok", label = "git", detail = git }
  else
    out[#out + 1] = { level = "error", label = "git", detail = "no está en el PATH" }
    out[#out + 1] = { level = "info", label = "  por qué", detail = "vim.pack clona con git; sin él no hay plugins" }
  end

  -- node y npm son requisito a partir de la fase 3, no ahora. Por eso van como
  -- `info` y no como `warn`: un aviso en cada `:Bpack doctor` hasta la fase 3
  -- sería ruido, y ruido es lo que hace que nadie lea un diagnóstico.
  for _, tool in ipairs({ "node", "npm" }) do
    local ver = first_line({ tool, "--version" })
    out[#out + 1] = ver
        and { level = "ok", label = tool, detail = ver }
        or { level = "info", label = tool, detail = "no está — necesario a partir de la fase 3 (LSP de JS/TS)" }
  end

  return out
end

--- ── Config y spec ──────────────────────────────────────────────────────────

--- @return bpack.Check[]
local function check_config()
  local out = {}
  local spec_path = engine.spec_path()
  local config_root = vim.fn.stdpath("config")

  out[#out + 1] = check_path("config (spec.lua)", spec_path, { need_exists = true })

  -- ¿Estamos corriendo el repo o la config instalada? Cambia dónde cae el lock,
  -- y por eso conviene decirlo en voz alta.
  local installed = vim.fs.dirname(vim.fs.dirname(spec_path)) == config_root
  if installed then
    out[#out + 1] = { level = "ok", label = "origen", detail = "config instalada en " .. config_root }
  else
    out[#out + 1] = {
      level = "info",
      label = "origen",
      detail = "checkout de desarrollo: " .. spec_path,
    }
    out[#out + 1] = {
      level = "info",
      label = "  lock",
      detail = "cae en " .. engine.lock_path() .. ", fuera del repo",
    }
  end

  -- El spec tiene que seguir siendo parseable y conservar los marcadores: de
  -- eso dependen `:Bpack add` y `:Bpack del`, que reescriben el archivo.
  local raw = table.concat(vim.fn.readfile(spec_path), "\n")
  if not raw:find(">>> bpack:plugins", 1, true) or not raw:find("<<< bpack:plugins", 1, true) then
    out[#out + 1] = {
      level = "error",
      label = "spec (marcadores)",
      detail = "faltan los marcadores bpack:plugins — :Bpack add y :Bpack del no van a poder escribir",
    }
  else
    out[#out + 1] = { level = "ok", label = "spec (marcadores)", detail = "presentes" }
  end

  local chunk, err = loadstring(raw, "@" .. spec_path)
  if not chunk then
    out[#out + 1] = { level = "error", label = "spec (sintaxis)", detail = tostring(err) }
  else
    local ok_eval, value = pcall(chunk)
    if not ok_eval or type(value) ~= "table" then
      out[#out + 1] = { level = "error", label = "spec (sintaxis)", detail = "el spec no devuelve una tabla" }
    else
      out[#out + 1] = { level = "ok", label = "spec (sintaxis)", detail = "parsea" }
    end
  end

  return out
end

--- ── Disco ──────────────────────────────────────────────────────────────────

--- El pack dir es de `vim.pack`. La regla de oro del repo es que bpack no
--- escribe nunca adentro, y la forma más barata de upholdirla es mirar.
--- @return bpack.Check[]
local function check_pack_dir()
  local out = {}
  local dir = engine.pack_dir()

  if vim.fn.isdirectory(dir) == 0 then
    -- Todavía no se clonó nada. No es un problema.
    return { { level = "ok", label = "pack dir", detail = dir .. " (todavía no existe, normal sin plugins)" } }
  end

  if not writable(dir) then
    out[#out + 1] = { level = "error", label = "pack dir", detail = "sin permiso de escritura: " .. dir }
  else
    out[#out + 1] = { level = "ok", label = "pack dir", detail = dir }
  end

  -- Cada entrada tiene que ser un clon git válido, no sólo un directorio. El
  -- caso real que motiva el chequeo: la config anterior dejó
  -- `__no_start_dir__`, que es un *directorio* sin `.git`. Un chequeo de "sólo
  -- hay directorios" lo deja pasar, y el síntoma es un `fatal: not a git
  -- repository` que sale de `vim.pack` y no dice qué loivoló.
  local intruders = {}
  for name, kind in vim.fs.dir(dir) do
    local is_plug = kind == "directory"
      and vim.fn.isdirectory(vim.fs.joinpath(dir, name, ".git")) == 1
    if not is_plug then
      intruders[#intruders + 1] = name
    end
  end
  if #intruders > 0 then
    table.sort(intruders)
    out[#out + 1] = {
      level = "error",
      label = "pack dir (contenido)",
      detail = ("%d entrada(s) que no son clones git y rompen vim.pack: %s"):format(#intruders, table.concat(intruders, ", ")),
    }
    out[#out + 1] = {
      level = "info",
      label = "  por qué",
      detail = "vim.pack llama error() si el pack dir no es sólo un clon git válido por plugin",
    }
    out[#out + 1] = {
      level = "info",
      label = "  arreglo",
      detail = "borrá a mano lo que no sea un plugin, o :Bpack del <nombre>",
    }
  else
    out[#out + 1] = { level = "ok", label = "pack dir (contenido)", detail = "sólo clones git" }
  end

  return out
end

--- @return bpack.Check[]
local function check_state_and_log()
  return {
    check_path("state (bpack.json)", vim.fs.joinpath(util.state_dir(), "bpack.json"), { need_exists = false }),
    check_path("log", util.log_path(), { need_exists = false }),
  }
end

--- ── Plugins ────────────────────────────────────────────────────────────────

--- @return bpack.Check[]
local function check_plugins()
  local out = {}
  local spec = engine.spec()
  local declared = engine.declared()
  local locked = engine.locked()

  out[#out + 1] = {
    level = "ok",
    label = "plugins",
    detail = ("%d en el spec, %d en el lock"):format(#declared, #locked),
  }

  local problems = 0
  for _, r in ipairs(engine.status()) do
    if r.in_spec and not r.in_lock then
      problems = problems + 1
      out[#out + 1] = {
        level = "warn",
        label = "  " .. r.name,
        detail = "está en el spec pero no instalado — :Bpack sync",
      }
    elseif not r.in_spec and r.in_lock then
      problems = problems + 1
      out[#out + 1] = {
        level = "warn",
        label = "  " .. r.name,
        detail = "huérfano: en el disco, fuera del spec — :Bpack del " .. r.name,
      }
    elseif r.src_changed then
      problems = problems + 1
      out[#out + 1] = {
        level = "warn",
        label = "  " .. r.name,
        detail = "el spec cambió de repo — :Bpack del y :Bpack add de nuevo",
      }
    end
  end
  if problems == 0 and #declared > 0 then
    out[#out + 1] = { level = "ok", label = "  estado", detail = "spec y disco de acuerdo" }
  end

  -- `spec.config` y `spec.lazy` se llenan a mano. La falta de typos que se cuelan
  -- ahí es la clase de bug más común: la config de un plugin que ya no está, o
  -- que nunca estuvo.
  local in_spec = {}
  for _, d in ipairs(declared) do
    in_spec[d.name] = true
  end

  for kind, entries in pairs({ config = spec.config, lazy = spec.lazy }) do
    for name, _ in pairs(entries or {}) do
      if not in_spec[name] then
        out[#out + 1] = {
          level = "warn",
          label = ("spec.%s['%s']"):format(kind, name),
          detail = "no hay ningún plugin con ese nombre en el spec",
        }
      end
    end
  end

  return out
end

--- ── Atajos ─────────────────────────────────────────────────────────────────

--- @return bpack.Check[]
local function check_keys()
  local ok, keymap = pcall(require, "bpack.keymap")
  if not ok then
    return { { level = "error", label = "atajos", detail = "no se pudo cargar bpack.keymap: " .. tostring(keymap) } }
  end

  local declared = keymap.declared()
  if #declared == 0 then
    return { { level = "warn", label = "atajos", detail = "ninguno declarado" } }
  end

  local out = { { level = "ok", label = "atajos", detail = ("%d declarados"):format(#declared) } }

  local mapped, missing, blank = 0, {}, {}
  for _, k in ipairs(declared) do
    local found = false
    for _, m in ipairs(vim.api.nvim_get_keymap(k.mode or "n")) do
      if keymap.canonical_lhs(m.lhs) == keymap.canonical_lhs(k.lhs) then
        found = true
        break
      end
    end
    if found then
      mapped = mapped + 1
    else
      missing[#missing + 1] = k.lhs
    end
    if not k.desc or k.desc == "" then
      blank[#blank + 1] = k.lhs
    end
  end

  if #missing > 0 then
    out[#out + 1] = {
      level = "error",
      label = "  sin mapear",
      detail = ("%d de %d: %s"):format(#missing, #declared, table.concat(missing, ", ")),
    }
  end
  if #blank > 0 then
    out[#out + 1] = {
      level = "warn",
      label = "  sin desc",
      detail = ("%d atajo(s) sin descripción — :Bpack keys los muestra vacíos"):format(#blank),
    }
  end
  if #missing == 0 and #blank == 0 then
    out[#out + 1] = { level = "ok", label = "  estado", detail = ("%d/%d mapeados, todos con desc"):format(mapped, #declared) }
  end

  return out
end

--- ── Runner ─────────────────────────────────────────────────────────────────

--- Todas las comprobaciones, en orden.
--- @return {section: string, checks: bpack.Check[]}[]
function M.run()
  return {
    { section = "entorno", checks = check_nvim() },
    { section = "herramientas", checks = check_tools() },
    { section = "config", checks = check_config() },
    { section = "disco", checks = (function()
      local out = check_pack_dir()
      vim.list_extend(out, check_state_and_log())
      return out
    end)() },
    { section = "plugins", checks = check_plugins() },
    { section = "atajos", checks = check_keys() },
  }
end

--- @type table<string, string>
local MARKS = {
  ok = "✓",
  info = "·",
  warn = "!",
  error = "✗",
}

--- Dibuja los checks en un scratch. Devuelve el número de `error`.
--- @return integer errors, integer warnings
function M.report()
  local lines, errors, warnings = {}, 0, 0

  for _, group in ipairs(M.run()) do
    if #group.checks > 0 then
      -- El ancho sale de la sección, no de un número fijo: con nombres largos
      -- como `nvim-dap-virtual-text` una columna fija desalinea todas las
      -- marcas y el buffer deja de poder escanearse de un vistazo.
      local width = 0
      for _, c in ipairs(group.checks) do
        width = math.max(width, #c.label)
      end

      lines[#lines + 1] = group.section
      lines[#lines + 1] = string.rep("─", #group.section)
      for _, c in ipairs(group.checks) do
        if c.level == "error" then
          errors = errors + 1
        elseif c.level == "warn" then
          warnings = warnings + 1
        end
        lines[#lines + 1] = ("  %s %-" .. width .. "s  %s"):format(MARKS[c.level] or "?", c.label, c.detail or "")
      end
      lines[#lines + 1] = ""
    end
  end

  if errors == 0 and warnings == 0 then
    lines[#lines + 1] = "Todo en orden."
  else
    lines[#lines + 1] = ("%d error(es), %d aviso(s)."):format(errors, warnings)
  end
  lines[#lines + 1] = "Sólo lee. Para reparar: :Bpack sync, :Bpack del, :Bpack add."

  cmd.scratch("bpack doctor", lines, "bpack-doctor")
  return errors, warnings
end

--- `:Bpack doctor`
function M.cmd_doctor(_)
  util.log("doctor: corre")
  M.report()
end

function M.setup()
  cmd.register("doctor", M.cmd_doctor, "Diagnóstico de la config")
  return true
end

return M
