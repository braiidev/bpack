-- Punto de entrada de bpack: guarda de versión y orquestación del arranque.
--
-- El motor nativo es `vim.pack` (Neovim 0.12+), envuelto por nosotros. De él
-- tomamos la instalación y el lockfile; el lazy loading, los keymaps, los
-- temas y el self-update son nuestros. Ver `PLAN.md`, decisiones 1 a 6.
--
-- El guard de 0.12 no es paranoia: `vim.pack` no existe antes de 0.12 y un
-- `require` de él en una máquina vieja tira "attempt to index a nil value",
-- que no dice nada útil.

local util = require("bpack.util")

local M = {}

M.started = false

--- Orden de arranque. Cada entrada es un módulo de `lua/` con un `setup()`.
--- El orden importa: core define opciones y autocmds, y el resto lo consume.
--- @type string[]
local modules = { "core" }

--- Carga los módulos en orden. Cada uno dentro de `util.protect`, así que un
--- error en uno no impide que carguen los siguientes.
--- @return boolean ok  false si algún módulo falló
function M.setup()
  if vim.fn.has("nvim-0.12") == 0 then
    local msg = ("bpack necesita Neovim 0.12 o superior; esta es la %s. ")
      :format(tostring(vim.version()))
      .. "vim.pack no existe antes de 0.12. Actualizá Neovim."
    util.log("ABORT: %s", msg)
    util.notify(msg, vim.log.levels.ERROR)
    return false
  end

  util.log("arranque: Neovim %s, %d módulo(s)", tostring(vim.version()), #modules)

  for _, mod in ipairs(modules) do
    util.protect(mod, function()
      require(mod).setup()
    end)
  end

  M.started = true
  if #util.errors > 0 then
    util.log("arranque con %d error(es)", #util.errors)
    return false
  end
  util.log("arranque ok")
  return true
end

--- Registra un módulo en el orden de arranque. Lo usan los `init.lua` de cada
--- feature para no tener que editar esta lista.
--- @param name string
function M.register(name)
  modules[#modules + 1] = name
end

--- Los módulos registrados, para tests y para `bpack doctor`.
--- @return string[]
function M.modules()
  return vim.deepcopy(modules)
end

return M
