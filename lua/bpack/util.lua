-- Primitivas del gestor: log a disco, avisos, y el pcall que evita que un
-- modulo roto baje el arranque.
--
-- El log a disco no es opcional: `--headless` y el arranque de Neovim no
-- muestran output, asi que sin esto los errores se pierden. La config vieja
-- no tenia log y por eso un fallo de `vim.pack` aparecia como una pantalla
-- vacia.

local M = {}

local uv = vim.uv or vim.loop

--- Errores acumulados del arranque. Los lee `bpack doctor` para reportarlos.
--- @type {mod: string, err: string}[]
M.errors = {}

--- Directorio de estado de bpack.
---
--- Todo lo nuestro que no va en el repo vive acá y en ningún otro lado. En
--- particular NUNCA dentro del pack dir (`stdpath('data')/site/pack/core/opt`):
--- es territorio exclusivo de `vim.pack`, y el motor llama `error()` si
--- encuentra adentro algo que no sea un clon válido de git. Eso baja Neovim
--- entero, y fue el motivo exacto por el que la config vieja no arrancaba.
--- @return string
function M.state_dir()
  return vim.fs.joinpath(vim.fn.stdpath("state"), "bpack")
end

--- Crea el directorio de estado si falta.
--- @return string dir
function M.ensure_state_dir()
  local dir = M.state_dir()
  if uv.fs_stat(dir) == nil then
    vim.fn.mkdir(dir, "p")
  end
  return dir
end

--- Ruta del log de arranque.
--- @return string
function M.log_path()
  return vim.fs.joinpath(M.ensure_state_dir(), "bpack.log")
end

--- Log a disco. Acepta `fmt` con argumentos de `string.format`.
--- @param fmt string
--- @param ... any
function M.log(fmt, ...)
  local msg = select("#", ...) > 0 and fmt:format(...) or fmt
  local line = ("%s %s\n"):format(os.date("%Y-%m-%d %H:%M:%S"), msg)
  local fd = uv.fs_open(M.log_path(), "a", 420)
  if fd then
    uv.fs_write(fd, line, -1)
    uv.fs_close(fd)
  end
end

--- Aviso al usuario, con el prefijo del gestor.
--- @param msg string
--- @param level? integer
function M.notify(msg, level)
  vim.notify("[bpack] " .. msg, level or vim.log.levels.INFO)
end

--- Corre `fn` y registra el error en vez de propagarlo.
---
--- El arranque de Neovim no tiene red de seguridad: un `error()` no capturado
--- deja al usuario sin editor. Cada modulo entra por acá, así que uno roto se
--- reporta y el resto sigue.
--- @param mod string nombre del modulo, para el reporte
--- @param fn fun()
--- @return boolean ok
function M.protect(mod, fn)
  local ok, err = pcall(fn)
  if not ok then
    M.errors[#M.errors + 1] = { module = mod, err = tostring(err) }
    M.log("ERROR en %s:\n%s", mod, err)
    M.notify(
      ("error en '%s' — el resto de la config sigue. Log: %s"):format(mod, M.log_path()),
      vim.log.levels.ERROR
    )
  end
  return ok
end

return M
