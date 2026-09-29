-- bpack: el gestor. Todo lo nuestro entra por acá.
--
-- El rtp se antepone desde la ubicación de este archivo para que el repo se
-- pueda correr desde donde esté — `nvim -u ~/Dev/_nvim/init.lua`, los tests, la
-- migración. Una vez instalado en ~/.config/nvim ya está en el rtp y esto sólo
-- lo deja primero, que es lo que queremos igual.
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
vim.opt.runtimepath:prepend(root)

require("bpack").setup()
