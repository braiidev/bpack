-- Base del editor: opciones y autocmds. Cero plugins.
--
-- Se expone `setup()` y no ejecución en el cuerpo del módulo para que el orden
-- de arranque sea explícito: `bpack` decide cuándo entra cada cosa.

local M = {}

function M.setup()
  require("core.options").setup()
  require("core.autocmds").setup()
  return true
end

return M
