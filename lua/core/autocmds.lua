-- Autocmds base: comportamiento del editor, no de los plugins.
--
-- Va en un solo augroup con `clear = true` para que `bpack reload` sea
-- idempotente: recargar dos veces no duplica autocmds.

local options = require("core.options")

local M = {}

local group = vim.api.nvim_create_augroup("BpackCore", { clear = true })

--- Ventanas de solo lectura donde `q` cierra en vez de dejar un buffer
--- scratch atrás.
local scratch_filetypes = {
  TelescopePrompt = true,
  NvimTree = true,
  alpha = true,
  oil = true,
  ["neo-tree-preview"] = true,
}

--- Filetypes donde se recorta el espacio en blanco al final al guardar.
---
--- Es opinión, no corrección: por eso es una lista explícita y no una regla
--- global. En `make`, `gitcommit` o `help` los tabs son sintaxis, y en un `.md`
--- con salto de línea duro el final de línea es de veras dos espacios.
local trim_trailing = {
  lua = true,
  python = true,
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  css = true,
  json = true,
  yaml = true,
  sh = true,
}

function M.setup()
  local au = vim.api.nvim_create_autocmd

  -- Sangría por filetype (python, make, help...). Va primero porque el
  -- `FileType` dispara antes de que abra el primer plugin.
  au("FileType", {
    group = group,
    callback = function(args)
      local indent = options.indent_by_ft[args.match]
      if not indent then
        return
      end
      for opt, value in pairs(indent) do
        vim.opt_local[opt] = value
      end
    end,
  })

  -- `q` cierra las ventanas de solo lectura sin tocar el buffer.
  au("FileType", {
    group = group,
    callback = function(args)
      if not scratch_filetypes[args.match] then
        return
      end
      vim.bo[args.buf].buftype = "nofile"
      vim.bo[args.buf].bufhidden = "wipe"
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = args.buf, nowait = true, silent = true })
    end,
  })

  -- Crea el directorio al guardar en una ruta que no existe. Sin esto,
  -- `nvim ruta/nueva/archivo.lua` falla en el `:w` sin forma de recuperarlo
  -- desde la sesión.
  au("BufWritePre", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].buftype ~= "" or vim.fn.getbufvar(args.buf, "&modifiable") == 0 then
        return
      end
      local dir = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(args.buf), ":h")
      if dir ~= "" and vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end
    end,
  })

  au("BufWritePre", {
    group = group,
    callback = function(args)
      if not trim_trailing[vim.bo[args.buf].filetype] then
        return
      end
      local view = vim.fn.winsaveview()
      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
      local changed = false
      for i, line in ipairs(lines) do
        local trimmed = (line:gsub("%s+$", ""))
        if trimmed ~= line then
          lines[i] = trimmed
          changed = true
        end
      end
      if changed then
        vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)
        vim.fn.winrestview(view)
      end
    end,
  })

  -- Resalta lo último copiado o pegado. Sin esto, `TextYankPost` no hace nada
  -- visible y parece un hook muerto.
  au("TextYankPost", {
    group = group,
    callback = function()
      vim.hl.on_yank({ higroup = "BpackYank", timeout = 180 })
    end,
  })

  -- Mantiene el tamaño de los splits al redimensionar la terminal.
  au("VimResized", {
    group = group,
    callback = function()
      if vim.o.equalalways then
        vim.cmd("wincmd =")
      end
    end,
  })

  return true
end

return M
