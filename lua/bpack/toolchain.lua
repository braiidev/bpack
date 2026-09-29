-- La toolchain: binarios que bpack instala y controla.
--
-- Esto no es un gestor de plugins con otro nombre. Un plugin es un repo de Lua
-- que Neovim carga; una herramienta es un binario que corre por fuera, y no tiene
-- por qué hablar con Neovim en ningún momento. Lo que comparten es la idea: que
-- haya un spec, un lock y un comando de instalación, para que la respuesta a
-- "¿qué está instalado y por qué?" no dependa de lo que el sistema tenga.
--
-- Por qué no usamos lo que ya está en la máquina. Todo lo que hace falta para
-- los siete lenguajes ya vive en `/usr/bin` y en el npm global, y funciona. El
-- problema es otro: si `lua/lang/python.lua` apunta a `/usr/bin/ruff`, el
-- comportamiento del editor depende de lo que la máquina tenga instalado, y en
-- otra no está. Con el prefijo de bpack, la ruta la ponemos nosotros y es la
-- misma en todas partes.
--
-- El precio es duplicar lo que ya está, hasta que la fase 4 borre lo viejo. Es
-- un precio consciente: primero se prueba que anda, después se limpia.
--
-- Los shims son la parte que evita el problema de siempre. Si las herramientas
-- vivieran en `~/.local/opt/bpack-tools/bin`, habría que sumar ese directorio al
-- PATH, y eso significa editar el `.zshrc` de la shell del usuario. En vez de
-- eso, cada herramienta recibe un wrapper de tres líneas en `~/.local/bin`, que
-- ya está en el PATH. Así `ruff` funciona en Neovim y también en la terminal,
-- y bpack no toca un archivo que no le corresponde.

local cmd = require("bpack.cmd")
local util = require("bpack.util")

local M = {}

local uv = vim.uv or vim.loop

--- La raíz desde la que cuelgan las herramientas y los shims.
---
--- Existe el override `BPACK_TOOLS_ROOT` por una razón medida, no por gusto: el
--- Neovim de snap **ignora `$HOME`**. Comprobado — con `HOME=/tmp/x` en el
--- entorno, `vim.env.HOME` sigue valiendo el home real y `expand("~")` con él.
--- `XDG_*` sí lo respeta, pero `~/.local/bin` no es una ruta XDG, y `~/.local/opt`
--- tampoco. Sin este override no hay forma de probar una instalación sin
--- escribir en el home del usuario, que es exactamente lo que hay que evitar
--- antes de confiar en el comando.
--- @return string
function M.root()
  return vim.env.BPACK_TOOLS_ROOT or vim.fn.expand("~")
end

--- Dónde viven los binarios. No se puede cambiar: `lua/lang/` lo lee.
--- @return string
function M.prefix()
  return vim.fs.joinpath(M.root(), ".local", "opt", "bpack-tools")
end

--- Dónde van los shims. Ya está en el PATH; por eso no se edita el `.zshrc`.
--- @return string
function M.shim_dir()
  return vim.fs.joinpath(M.root(), ".local", "bin")
end

--- ¿Es un archivo regular? No un directorio con el nombre del binario.
---
--- Hace falta porque las dos mecánicas no dejan el binario en el mismo lugar.
--- npm lo deja en `<prefix>/bin/<nombre>`, pero un release lo descomprime en
--- `<prefix>/<nombre>/<nombre>`. Sin esta comprobación, `prefix/ruff` —que es un
--- directorio— se tomaría por el ejecutable, el shim apuntaría a un directorio,
--- y `exec` fallaría recién cuando se use la herramienta: el peor momento
--- posible para enterarse.
--- @param p string
--- @return boolean
local function is_file(p)
  local st = uv.fs_stat(p)
  return st ~= nil and st.type == "file"
end

--- Ruta absoluta de una herramienta ya instalada, o nil si no está.
---
--- Es lo que van a usar los archivos de lenguaje: una ruta estable, no un
--- `vim.fn.executable` que puede encontrar cualquier cosa en el PATH.
---
--- Los candidatos están en el orden en que se prueban, y cada uno existe
--- porque una de las dos mecánicas lo produce:
---   - `npm install --prefix` deja los ejecutables en `node_modules/.bin/`.
---     No en `bin/`: es tentador ponerlo ahí y se descubre tarde, cuando la
---     herramienta ya se Cree instalar bien y sin shim.
---   - un release descomprimido deja `<prefijo>/<nombre>/<nombre>`.
--- @param name string
--- @return string|nil
function M.bin_path(name)
  local candidates = {
    vim.fs.joinpath(M.prefix(), "node_modules", ".bin", name), -- npm --prefix
    vim.fs.joinpath(M.prefix(), name, name), -- release: <prefix>/<name>/<name>
    vim.fs.joinpath(M.prefix(), name), -- release con el binario en la raíz
  }
  for _, p in ipairs(candidates) do
    if is_file(p) then
      return p
    end
  end
  return nil
end

--- La plataforma, como la nombran los releases de GitHub.
--- @return string|nil
function M.platform()
  local u = uv.os_uname()
  local arch = ({ x86_64 = "x86_64", amd64 = "x86_64", aarch64 = "aarch64", arm64 = "aarch64" })[u.machine]
  if not arch then
    return nil
  end
  local sys = u.sysname:lower()
  if sys == "darwin" then
    return "darwin-" .. arch
  elseif sys == "linux" then
    return "linux-" .. arch
  end
  return nil
end

--- Corre un comando esperando el resultado.
--- @param argv string[]
--- @param timeout_ms? integer
--- @return {out: string, err: string, code: integer}
local function run(argv, timeout_ms)
  local r = vim.system(argv, { text = true }):wait(timeout_ms or 120000)
  return { out = r.stdout or "", err = r.stderr or "", code = r.code }
end

--- Baja una URL a un archivo. Devuelve el error, o nil si salió bien.
--- @param url string
--- @param dest string
--- @return string|nil err
local function download(url, dest)
  local curl = vim.fn.executable("curl") == 1 and "curl" or nil
  if not curl then
    return "no hay curl en el PATH para bajar " .. url
  end
  local r = run({ curl, "-fsSL", "--retry", "3", "-o", dest, url })
  if r.code ~= 0 then
    return ("curl salió con %d: %s"):format(r.code, (r.err ~= "" and r.err or r.out):gsub("%s*\n.*", ""))
  end
  return nil
end

--- Instala una herramienta de tipo `release`: un artefacto comprimido de GitHub.
--- @param name string
--- @param tool table
--- @return boolean ok, string detalle
function M.install_release(name, tool)
  local plat = M.platform()
  if not plat then
    return false, ("plataforma sin soporte: %s"):format(uv.os_uname().sysname .. "/" .. uv.os_uname().machine)
  end
  local target = tool.targets and tool.targets[plat]
  if not target then
    return false, ("el release no trae artefacto para %s"):format(plat)
  end
  if vim.fn.executable("tar") ~= 1 then
    return false, "no hay tar en el PATH"
  end

  local dir = vim.fs.joinpath(M.prefix(), name)
  vim.fn.mkdir(dir, "p")

  local asset = (tool.asset or "%s"):format(target)
  -- El `url` del spec es una plantilla con un `%s` para la versión, y ya termina
  -- en `/`. Concatenar la versión antes de aplicar `format` dejaba un `%s` sin
  -- argumento en la mitad de la cadena.
  local url = (tool.url:format(tool.version)) .. asset

  local tmp = vim.fs.joinpath(vim.fn.tempname(), ".tgz")
  vim.fn.mkdir(vim.fs.dirname(tmp), "p")

  local err = download(url, tmp)
  if err then
    return false, err
  end

  -- `--strip-components=1`: los releases de ruff cuelgan el binario de un
  -- subdirectorio con el nombre del release. Sin esto, `M.bin_path` no lo
  -- encuentra y el shim apunta a la nada.
  local r = run({ "tar", "-xzf", tmp, "-C", dir, "--strip-components=1" })
  vim.fn.delete(tmp)
  if r.code ~= 0 then
    return false, ("tar salió con %d: %s"):format(r.code, r.err)
  end

  return true, url
end

--- Instala una herramienta de tipo `npm`: paquete en el prefijo, sin `-g`.
--- @param name string
--- @param tool table
--- @return boolean ok, string detalle
function M.install_npm(name, tool)
  if vim.fn.executable("npm") ~= 1 then
    return false, "no hay npm en el PATH"
  end
  vim.fn.mkdir(M.prefix(), "p")

  local pkg = ("%s@%s"):format(tool.pkg or name, tool.version)
  -- `--prefix` en vez de `-g`: la diferencia entre "lo instala bpack" y "me
  -- contamination el sistema". Con `-g` el binario queda en el npm global y
  -- `lua/lang/` no tiene una ruta que controlar.
  local r = run({ "npm", "install", "--prefix", M.prefix(), "--no-save", "--silent", pkg }, 300000)
  if r.code ~= 0 then
    return false, ("npm salió con %d: %s"):format(r.code, (r.err ~= "" and r.err or r.out):gsub("%s*\n.*", ""))
  end
  return true, pkg
end

--- Escribe el shim de una herramienta.
---
--- Se escribe aunque el destino no exista todavía: `install.sh` corre esto
--- después de instalar, pero un shim roto es peor que uno ausente — el segundo
--- se ve, el primero truena en silencio.
--- @param name string
--- @param tool table
--- @return boolean ok, string detalle
function M.write_shim(name, tool)
  local dir = M.shim_dir()
  if uv.fs_stat(dir) == nil then
    vim.fn.mkdir(dir, "p")
  end

  local real = M.bin_path(name)
  if not real then
    return false, "no encuentro el binario instalado para " .. name
  end
  if real == vim.fs.joinpath(dir, name) then
    return true, "ya era el shim"
  end

  local p = vim.fs.joinpath(dir, name)
  local fd = uv.fs_open(p, "w", 493) -- 0755
  if not fd then
    return false, ("no pude escribir %s"):format(p)
  end
  -- `exec` y no un if: el shim tiene que reemplazar su proceso, o las señales
  -- de Ctrl-C y el exit code le quedan al wrapper en vez de a la herramienta.
  uv.fs_write(fd, ("#!/bin/sh\n# shim de bpack — generado, no editar a mano\nexec %q \"$@\"\n"):format(real), -1)
  uv.fs_close(fd)
  return true, p
end

--- Qué falta, qué está, y qué no se puede instalar acá.
---
--- "Instalada" significa las dos cosas: el binario existe **y** tiene su shim.
--- Reportar sólo el binario sería el falso positivo más caro de este módulo:
--- `install` vería que está, no haría nada, y el usuario descubriría que `ruff`
--- no está en el PATH recién cuando lo invoca.
--- @return {name: string, desc: string|nil, kind: string, version: string|nil, state: string, detail: string|nil}[]
function M.status()
  local engine = require("bpack.engine")
  local tools = engine.spec().tools or {}
  local out = {}
  local names = vim.tbl_keys(tools)
  table.sort(names)
  for _, name in ipairs(names) do
    local tool = tools[name]
    local path = M.bin_path(name)
    local shim = vim.fs.joinpath(M.shim_dir(), name)
    local entry = { name = name, desc = tool.desc, kind = tool.kind, version = tool.version }
    if path and is_file(shim) then
      entry.state = "instalada"
      entry.detail = path
    elseif path then
      entry.state = "sin shim"
      entry.detail = ("el binario está en %s pero falta el shim en %s"):format(path, shim)
    elseif tool.kind == "release" and tool.targets and not tool.targets[M.platform() or ""] then
      entry.state = "sin soporte"
      entry.detail = ("no hay artefacto para %s"):format(M.platform() or "plataforma desconocida")
    else
      entry.state = "falta"
    end
    out[#out + 1] = entry
  end
  return out
end

--- Instala las que falten.
--- @param names string[]
--- @return integer ok_count, integer fail_count
function M.install(names)
  local engine = require("bpack.engine")
  local tools = engine.spec().tools or {}
  local ok_n, fail_n = 0, 0

  for _, name in ipairs(names) do
    local tool = tools[name]
    if not tool then
      util.notify(("no conozco la herramienta %q"):format(name), vim.log.levels.ERROR)
      fail_n = fail_n + 1
    elseif M.bin_path(name) then
      -- El binario está pero puede faltar el shim, que es el caso que falló
      -- antes: `install` decia "ya está" y no reparaba nada. Ahora siempre
      -- pasa por acá y el shim se (re)escribe.
      local sok, spath = M.write_shim(name, tool)
      if sok then
        util.notify(("%s ya está en %s — shim en %s"):format(name, M.bin_path(name), spath))
        ok_n = ok_n + 1
      else
        util.log("install %s: el binario esta pero no se pudo escribir el shim: %s", name, spath)
        util.notify(("%s está instalada pero sin shim: %s"):format(name, spath), vim.log.levels.ERROR)
        fail_n = fail_n + 1
      end
    else
      util.notify("instalando " .. name .. "...")
      local ok, detail
      if tool.kind == "npm" then
        ok, detail = M.install_npm(name, tool)
      else
        ok, detail = M.install_release(name, tool)
      end
      if ok then
        local sok, spath = M.write_shim(name, tool)
        if sok then
          util.notify(("%s instalada (%s) — shim en %s"):format(name, detail, spath))
          ok_n = ok_n + 1
        else
          util.notify(("%s instalada pero sin shim: %s"):format(name, spath), vim.log.levels.ERROR)
          fail_n = fail_n + 1
        end
      else
        util.log("install %s fallo: %s", name, detail)
        util.notify(("%s no se pudo instalar: %s"):format(name, detail), vim.log.levels.ERROR)
        fail_n = fail_n + 1
      end
    end
  end
  return ok_n, fail_n
end

--- `:Bpack install [nombre...]`
---
--- Sin argumentos instala todo lo que falte, **preguntando antes**. El `!` se
--- saltea la pregunta, que es lo que necesitan los scripts: `install.sh` no
--- tiene a nadie contestando.
--- @param args string
function M.cmd_install(args)
  local spec_tools = require("bpack.engine").spec().tools or {}
  local all = vim.tbl_keys(spec_tools)
  table.sort(all)

  local names = {}
  local body = vim.trim((args:gsub("^%s*!", "")))
  if body == "" then
    names = all
  else
    for word in body:gmatch("%S+") do
      names[#names + 1] = word
    end
  end
  if #names == 0 then
    return util.notify("el spec no declara ninguna herramienta")
  end

  local st = M.status()
  local pending, skipped = {}, {}
  for _, e in ipairs(st) do
    if vim.tbl_contains(names, e.name) then
      if e.state == "falta" or e.state == "sin shim" then
        pending[#pending + 1] = e
      elseif e.state == "sin soporte" then
        skipped[#skipped + 1] = e
      end
    end
  end

  -- Un nombre que no está en el spec no es "nada pendiente": es un error de
  -- tipeo, y decir que no falta nada manda al usuario a otro lado.
  local unknown = vim.tbl_filter(function(n)
    return not spec_tools[n]
  end, names)
  if #unknown > 0 then
    util.notify(
      ("no conozco %s. En el spec hay: %s"):format(table.concat(unknown, ", "), table.concat(all, ", ")),
      vim.log.levels.ERROR
    )
    return
  end

  if #pending == 0 then
    if #skipped > 0 then
      return util.notify(
        ("no falta ninguna. %d no se pueden instalar acá: %s"):format(
          #skipped,
          table.concat(
            vim.tbl_map(function(e)
              return e.name
            end, skipped),
            ", "
          )
        )
      )
    end
    return util.notify("no falta ninguna herramienta")
  end

  local lines = { "Falta instalar:", "" }
  for _, e in ipairs(pending) do
    lines[#lines + 1] = ("  %-14s %-8s %s"):format(e.name, e.version or "?", e.desc or "")
  end
  if #skipped > 0 then
    lines[#lines + 1] = ""
    lines[#lines + 1] = ("  y %d que no se pueden instalar en esta plataforma:"):format(#skipped)
    for _, e in ipairs(skipped) do
      lines[#lines + 1] = ("    %-12s %s"):format(e.name, e.detail or "")
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  en:   " .. M.prefix()
  lines[#lines + 1] = "  shim: " .. M.shim_dir()
  cmd.scratch("bpack install", lines, "bpack-doctor")

  if args:sub(1, 1) ~= "!" then
    local answer = vim.fn.confirm("¿Instalo " .. #pending .. " herramienta(s)?", "&Sí\n&No", 2)
    if answer ~= 1 then
      return util.notify("cancelado")
    end
  end

  if #skipped > 0 then
    util.notify(("%d no se pueden instalar en esta plataforma, las salto"):format(#skipped))
  end

  local todo = vim.tbl_map(function(e)
    return e.name
  end, pending)
  local ok_n, fail_n = M.install(todo)

  if fail_n == 0 then
    return util.notify(("%d herramienta(s) lista(s). Abrí un shell nuevo para que el PATH las vea."):format(ok_n))
  end
  util.notify(("%d ok, %d fallaron. El detalle en %s"):format(ok_n, fail_n, util.log_path()), vim.log.levels.WARN)
end

function M.setup()
  cmd.register("install", M.cmd_install, "Instalar las herramientas de la toolchain, en el prefijo de bpack")
  return true
end

return M
