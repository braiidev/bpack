--- `:Bpack selfupdate` — trae el repo-config y resincroniza, con vuelta atrás.
---
--- La config de Neovim no tiene paso de build: lo que se commitea es lo que
--- corre. Eso hace que un `selfupdate` sea riesgoso de una forma que en un
--- gestor común no lo es — acá un pull puede dejar al usuario sin editor, y la
--- próxima vez que abra Neovim va a fallar igual.
---
--- Por eso el rollback no es un extra: es la mitad de la task. El flujo es
--- guardar el commit viejo, traer el nuevo, **probar la config nueva en un
--- proceso aparte**, y si esa prueba falla, volver al commit viejo. La prueba
--- tiene que ser en un hijo: el Neovim que corre `:Bpack selfupdate` tiene
--- cargada la config *vieja* en memoria y no puede judge a la nueva.
---
--- `:Bpack selfupdate!` saltea la prueba del hijo y se fía del log del proceso
--- actual. Sólo para cuando la config ya está tan rota que ni el hijo arranca.

local cmd = require("bpack.cmd")
local util = require("bpack.util")

local M = {}

local engine = require("bpack.engine")

--- Cuánto se espera al hijo antes de darlo por colgado.
--- @type integer
local HEALTH_TIMEOUT_MS = 8000

--- Corre un comando y devuelve stdout, exit code y stderr.
--- @param argv string[]
--- @return {out: string, err: string, code: integer}
local function run(argv)
  local result = vim.system(argv, { text = true }):wait(HEALTH_TIMEOUT_MS)
  if result.code == 124 or result.signal ~= 0 then
    return { out = result.stdout or "", err = result.stderr or "", code = -1 }
  end
  return { out = result.stdout or "", err = result.stderr or "", code = result.code }
end

--- La raíz de la config, que es la raíz del repo.
--- @return string
function M.root()
  return vim.fn.stdpath("config")
end

--- ¿Estamos en un checkout de git?
--- @return boolean
function M.is_repo()
  return vim.fn.isdirectory(vim.fs.joinpath(M.root(), ".git")) == 1
end

--- Cambios sin commitear. El rollback hace `reset --hard`, así que cualquier
--- cosa sin commitear se perdería: por eso abortamos en vez de arriesgar.
--- @return string[] paths
function M.dirty_paths()
  local out = {}
  local r = run({ "git", "-C", M.root(), "status", "--porcelain" })
  if r.code ~= 0 then
    return out
  end
  for _, line in ipairs(vim.split(r.out, "\n", { trimempty = true })) do
    out[#out + 1] = line
  end
  return out
end

--- ── Prueba de salud ────────────────────────────────────────────────────────

--- @alias bpack.Health '"healthy"'|'"broken"'|'"unknown"'

--- Arranca la config de disco en un Neovim hijo y lee el log.
---
--- El criterio de salud es el log, no el exit code. Nuestra config se protege
--- con `util.protect`: un módulo roto deja el arranque en exit 0 y sólo escribe
--- `ERROR en <módulo>` en el log. Un `exit == 0` como "está sano" sería
--- justamente el falso positivo más caro que hay acá.
---
--- @return bpack.Health health, string detalle
function M.probe()
  local log = util.log_path()
  local offset = vim.uv.fs_stat(log) and vim.uv.fs_stat(log).size or 0

  local root = M.root()
  local argv = {
    vim.v.progpath,
    "--headless",
    "-u",
    vim.fs.joinpath(root, "init.lua"),
    "-c",
    "lua vim.defer_fn(function() vim.cmd('qa!') end, 60)",
  }
  local r = run(argv)

  if r.code == -1 then
    return "unknown", "el Neovim hijo no terminó (se cuelgó o lo mataron)"
  end

  -- ReadFile y no `readfile`: `readfile` sobre un archivo appendeado puede leer
  -- una línea a medias, y una línea a medias no dice nada.
  local raw = vim.uv.fs_open(log, "r", 420)
  if not raw then
    return "unknown", "no se pudo leer el log: " .. log
  end
  local stat = vim.uv.fs_fstat(raw)
  local size = stat and stat.size or 0
  if size <= offset then
    vim.uv.fs_close(raw)
    return "unknown", ("la config nueva no escribió nada en el log (¿%d bytes antes, %d ahora?)"):format(offset, size)
  end
  local data = vim.uv.fs_read(raw, size - offset, offset)
  vim.uv.fs_close(raw)

  if r.code ~= 0 then
    return "broken", ("el hijo salió con código %d. %s"):format(r.code, (r.err:gsub("\n", " ")))
  end

  local failures = {}
  for _, line in ipairs(vim.split(data, "\n", { trimempty = true })) do
    local mod = line:match("ERROR en ([^:]+):")
    if mod then
      failures[#failures + 1] = mod
    end
  end

  if #failures > 0 then
    return "broken", ("el log dice que falló: %s"):format(table.concat(failures, ", "))
  end
  return "healthy", ("el hijo arrancó limpio y escribió %d bytes en el log"):format(size - offset)
end

--- ── El comando ─────────────────────────────────────────────────────────────

--- Ejecuta un paso de git, reportando el fallo en vez de tragárselo.
--- @param argv string[]
--- @return boolean ok, string detalle
local function git(argv)
  local r = run(vim.list_extend({ "git", "-C", M.root() }, argv))
  if r.code ~= 0 then
    return false, (r.err ~= "" and r.err or r.out):gsub("\n%s*", " "):gsub("^%s+", "")
  end
  return true, (r.out:gsub("%s+$", ""))
end

--- `:Bpack selfupdate`
--- @param args string
function M.cmd_selfupdate(args)
  local skip_probe = args:sub(1, 1) == "!"
  util.log("selfupdate: empieza (probe=%s)", tostring(not skip_probe))

  -- 1. Condiciones para poder volver atrás sin perder nada.
  if not M.is_repo() then
    return util.notify(
      ("%s no es un checkout de git — no hay nada que traer"):format(M.root()),
      vim.log.levels.ERROR
    )
  end

  local dirty = M.dirty_paths()
  if #dirty > 0 then
    local lines = { "Hay cambios sin commitear. El rollback descarta todo lo que no esté commiteado, así que no sigo:", "" }
    for _, p in ipairs(dirty) do
      lines[#lines + 1] = "  " .. p
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Commitealos, o stashéalos, y volvé a correr."
    cmd.scratch("bpack selfupdate", lines, "bpack-doctor")
    return util.notify("árbol con cambios sin commitear — no toco nada", vim.log.levels.WARN)
  end

  -- 2. Guardar el commit al que hay que volver.
  local ok_old, old_sha = git({ "rev-parse", "HEAD" })
  if not ok_old then
    return util.notify("no pude leer el HEAD actual: " .. old_sha, vim.log.levels.ERROR)
  end
  util.log("selfupdate: veníamos de %s", old_sha)

  -- 3. Traer. `--ff-only` para que un origen divergido falle en vez de hacer
  --    un merge: acá un merge automático de la config no es lo que nadie quiere.
  local ok_pull, detail = git({ "pull", "--ff-only" })
  if not ok_pull then
    util.log("selfupdate: pull fallo: %s", detail)
    return util.notify("el pull falló, no se tocó nada: " .. detail, vim.log.levels.ERROR)
  end

  -- `git()` devuelve `ok, detalle`: si se toma un solo valor se recibe el `ok`,
  -- no el sha, y `new_sha` termina siendo `true`.
  local ok_new, new_sha = git({ "rev-parse", "HEAD" })
  if not ok_new or new_sha == old_sha then
    util.log("selfupdate: ya estaba al dia")
    return util.notify(("ya estabas al día (%s)"):format(old_sha:sub(1, 7)))
  end
  util.log("selfupdate: ahora en %s", new_sha)

  -- 4. Resync de plugins con el spec nuevo.
  local synced = engine.add()
  if not synced.ok then
    util.log("selfupdate: el resync fallo: %s", tostring(synced.err))
  end

  -- 5. Probar la config nueva. Este proceso tiene la vieja en memoria; el hijo
  --    es el único que puede decir si la de disco arranca.
  if skip_probe then
    util.log("selfupdate: probe salteado por el usuario")
    return util.notify(("actualizado a %s — sin probar, fijate vos"):format(new_sha:sub(1, 7)))
  end

  local health, why = M.probe()
  if health == "healthy" then
    util.log("selfupdate: sano (%s)", why)
    return util.notify(("actualizado a %s — la config nueva arranca"):format(new_sha:sub(1, 7)))
  end

  if health == "unknown" then
    -- No se sabe. No se revierte a ciegas: se avisa y se deja la decisión al
    -- usuario, con el comando a mano.
    util.log("selfupdate: salud desconocida: %s", why)
    return util.notify(
      ("actualizado a %s pero no pude verificarlo: %s. Si algo falla: git -C %s reset --hard %s"):format(
        new_sha:sub(1, 7),
        why,
        M.root(),
        old_sha:sub(1, 7)
      ),
      vim.log.levels.WARN
    )
  end

  -- 6. No aguantó. Volver.
  util.log("selfupdate: la config nueva esta rota (%s), revirtiendo a %s", why, old_sha)
  local ok_back, back_detail = git({ "reset", "--hard", old_sha })
  if not ok_back then
    return util.notify(
      ("la config nueva está rota Y el rollback falló: %s. Volvé a mano con: git -C %s reset --hard %s"):format(
        back_detail,
        M.root(),
        old_sha
      ),
      vim.log.levels.ERROR
    )
  end

  engine.add()

  local lines = {
    "Se revirtió el update: la config nueva no arrancaba.",
    "",
    "  desde   " .. new_sha:sub(1, 7),
    "  voltou a " .. old_sha:sub(1, 7),
    "",
    "  por qué: " .. why,
    "",
    "La config nueva sigue en el repo, sólo quedó sin aplicar. Para verla:",
    "  git -C " .. M.root() .. " log -1 " .. new_sha,
    "  git -C " .. M.root() .. " diff " .. old_sha .. " " .. new_sha,
  }
  cmd.scratch("bpack selfupdate", lines, "bpack-doctor")
  return util.notify(("update revertido a %s — la nueva no arrancaba"):format(old_sha:sub(1, 7)), vim.log.levels.WARN)
end

function M.setup()
  cmd.register("selfupdate", M.cmd_selfupdate, "Traer el repo-config y resincronizar, con rollback")
  return true
end

return M
