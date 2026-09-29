-- Índice de atajos del gestor. Fuente única de los atajos de núcleo.
--
-- Formato de cada entrada, en orden:
--
--   { modo, lhs, rhs, desc [, grupo] }
--
--   modo   "n", "v", "i", "t", ... o una lista de modos.
--   lhs    lado izquierdo. El leader se escribe `<leader>` y lo resuelve
--          `bpack.keymap`; el valor sale de `leader` de este mismo archivo.
--   rhs    lado derecho: string de keys o función.
--   desc   OBLIGATORIA. Sin descripción la entrada es inválida y el arranque
--          lo reporta. Es lo que alimenta `:Bpack keys` y `doc/bpack.txt`.
--   grupo  opcional, para agrupar en `:Bpack keys`.
--
-- Los atajos que agregan features (telescope, LSP, terminal, git) NO van acá:
-- los registra la feature en su propio `setup()` con un `desc`, y aparecen
-- igual en `:Bpack keys` porque el comando lee el estado vivo del editor.
--
-- Criterio de los atajos: el prefijo doble `<leader><leader>` agrupa por
-- concepto — `w` ventanas, `s` splits, `t` tabs, `b` buffers — y el sufijo es
-- siempre la misma letra. Con eso no hay colisiones ni atajos que se pisen.

return {
  leader = " ",
  localleader = " ",

  entries = {
    -- ── Guardar y salir ───────────────────────────────────────────────
    { "n", "<C-s>", "<cmd>write<cr>", "Guardar", "general" },
    { "i", "<C-s>", "<esc><cmd>write<cr>", "Guardar y volver a normal", "general" },
    { "n", "<C-q>", "<cmd>quitall<cr>", "Salir de Neovim", "general" },

    -- `jk` y `kj` salen del insert mode. Se mappean en insert y en select.
    { "i", "jk", "<esc>", "Volver a normal", "general" },
    { "i", "kj", "<esc>o", "Volver a normal y abrir línea", "general" },
    { "x", "jk", "<esc>", "Volver a normal", "general" },

    -- ── Ventanas ──────────────────────────────────────────────────────
    { "n", "<C-h>", "<C-w>h", "Ventana de la izquierda", "ventanas" },
    { "n", "<C-j>", "<C-w>j", "Ventana de abajo", "ventanas" },
    { "n", "<C-k>", "<C-w>k", "Ventana de arriba", "ventanas" },
    { "n", "<C-l>", "<C-w>l", "Ventana de la derecha", "ventanas" },

    { "n", "<leader><leader>wh", "<C-w>h", "Ir a la ventana izquierda", "ventanas" },
    { "n", "<leader><leader>wj", "<C-w>j", "Ir a la ventana de abajo", "ventanas" },
    { "n", "<leader><leader>wk", "<C-w>k", "Ir a la ventana de arriba", "ventanas" },
    { "n", "<leader><leader>wl", "<C-w>l", "Ir a la ventana de la derecha", "ventanas" },

    -- Mayúscula = intercambiar, no enfocar. Es el mismo criterio de Vim.
    { "n", "<leader><leader>WH", "<C-w>H", "Mover la ventana a la izquierda", "ventanas" },
    { "n", "<leader><leader>WJ", "<C-w>J", "Mover la ventana abajo", "ventanas" },
    { "n", "<leader><leader>WK", "<C-w>K", "Mover la ventana arriba", "ventanas" },
    { "n", "<leader><leader>WL", "<C-w>L", "Mover la ventana a la derecha", "ventanas" },

    -- ── Splits ────────────────────────────────────────────────────────
    -- `|` y `-` son los caracteres que ya representan la forma del split.
    { "n", "<leader><leader>s|", "<C-w>v", "Split vertical (al lado)", "splits" },
    { "n", "<leader><leader>s-", "<C-w>s", "Split horizontal (abajo)", "splits" },
    { "n", "<leader><leader>sq", "<C-w>q", "Cerrar la ventana", "splits" },
    { "n", "<leader><leader>so", "<C-w>o", "Cerrar las otras ventanas", "splits" },
    { "n", "<leader><leader>se", "<C-w>=", "Igualar el tamaño de las ventanas", "splits" },
    -- Ojo con la dirección: `<` achica y `>` agranda el ancho.
    { "n", "<leader><leader>s<", "<C-w><", "Reducir el ancho", "splits" },
    { "n", "<leader><leader>s>", "<C-w>>", "Aumentar el ancho", "splits" },

    -- ── Tabs ──────────────────────────────────────────────────────────
    { "n", "<leader><leader>tn", "<cmd>tabnew<cr>", "Tab nueva", "tabs" },
    { "n", "<leader><leader>th", "<cmd>tabprev<cr>", "Tab anterior", "tabs" },
    { "n", "<leader><leader>tl", "<cmd>tabnext<cr>", "Tab siguiente", "tabs" },
    { "n", "<leader><leader>tc", "<cmd>tabclose<cr>", "Cerrar tab", "tabs" },
    { "n", "<leader><leader>to", "<cmd>tabonly<cr>", "Cerrar las otras tabs", "tabs" },
    {
      "n",
      "<leader><leader>tg",
      function()
        -- No hay `:tabgoto`; se pregunta el número y se salta con `:tabnext`.
        vim.ui.input({ prompt = ("Tab (1-%d): "):format(vim.fn.tabpagenr("$")) }, function(input)
          local n = tonumber(input)
          if n and n >= 1 and n <= vim.fn.tabpagenr("$") then
            vim.cmd.tabnext(n)
          end
        end)
      end,
      "Ir a la tab N",
      "tabs",
    },

    -- ── Buffers ───────────────────────────────────────────────────────
    { "n", "<leader><leader>bn", "<cmd>bnext<cr>", "Buffer siguiente", "buffers" },
    { "n", "<leader><leader>bp", "<cmd>bprev<cr>", "Buffer anterior", "buffers" },
    { "n", "<leader><leader>bd", "<cmd>bdelete<cr>", "Cerrar buffer", "buffers" },
    {
      "n",
      "<leader><leader>bo",
      function()
        local actual = vim.api.nvim_get_current_buf()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if buf ~= actual and vim.bo[buf].buftype == "" then
            vim.api.nvim_buf_delete(buf, {})
          end
        end
      end,
      "Cerrar los otros buffers",
      "buffers",
    },
    { "n", "<leader><leader>bl", "<cmd>buffers<cr>", "Lista de buffers", "buffers" },

    -- ── Editar ────────────────────────────────────────────────────────
    -- El recentrado lo hace `scrolloff`, no un `zz` embebido en el movimiento:
    -- así `.` repite lo que hiciste y no un `zz` que nadie pidió.
    { "n", "<A-j>", "<cmd>move .+1<cr>==", "Bajar la línea", "editar" },
    { "n", "<A-k>", "<cmd>move .-2<cr>==", "Subir la línea", "editar" },
    { "v", "<A-j>", ":move '>+1<cr>gv=gv", "Bajar el bloque", "editar" },
    { "v", "<A-k>", ":move '<-2<cr>gv=gv", "Subir el bloque", "editar" },

    -- `<C-d>` deja de ser scroll de media página y pasa a buscar la próxima
    -- ocurrencia y seleccionarla, como en VSCode.
    { "n", "<C-d>", "*gn", "Buscar y seleccionar la siguiente", "editar" },
    { "v", "<C-d>", "y*gn", "Buscar y agregar la siguiente", "editar" },

    { "n", "<Esc>", "<cmd>nohlsearch<cr>", "Limpiar la búsqueda", "editar" },
    { "v", "<Esc>", "<cmd>nohlsearch<cr><esc>", "Limpiar la búsqueda y salir de visual", "editar" },

    -- ── Colores ───────────────────────────────────────────────────────
    -- El tema es preferencia de la máquina, no del repo: se guarda en
    -- `state.json` y sobrevive al cierre.
    { "n", "<leader><leader>ct", "<cmd>Bpack theme<cr>", "Cambiar de tema", "colores" },
    { "n", "<leader><leader>cl", "<cmd>Bpack theme list<cr>", "Listar los temas", "colores" },
  },
}
