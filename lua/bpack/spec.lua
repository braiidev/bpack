-- El spec: qué plugins existen, cuál es la fuente de verdad de cada uno.
--
-- Tres tablas con tres dueños distintos, y por eso están separadas:
--
--   plugins  lo escribe `:Bpack add` y `:Bpack del`. Lista plana de repos.
--   config   lo escribe una persona, a mano. Función por plugin.
--   lazy     lo escribe una persona. Evento de `User` que dispara la carga.
--
-- La separación es deliberada: `:Bpack add` tiene que editar este archivo, y si
-- las funciones vivieran en la misma lista, cada add tendría que serializar Lua
-- que no entiende — o peor, pisar código que alguien escribió a mano. Con las
-- tablas separadas, el add sólo toca su propia lista y nunca puede romper la
-- config.
--
-- `plugins` es la lista de lo que debe estar instalado. Un repo en el disco que
-- no esté acá es un huérfano: `:Bpack list` lo marca y `:Bpack sync` no lo
-- borra, porque borrar el trabajo del usuario no es un efecto secundario de un
-- sync.

return {
  -- ── Lo escribe la máquina ───────────────────────────────────────────────
  -- Los marcadores encierran exactamente la asignación, y `bpack.engine` reemplaza
  -- todo lo que hay entre ellos. Si se edita a mano, se editan los valores,
  -- nunca los marcadores.
  -- >>> bpack:plugins
  plugins = {},
  -- <<< bpack:plugins

  -- ── Lo escribe una persona ──────────────────────────────────────────────
  --- Config por plugin. La clave es el nombre del directorio, no el repo:
  --- `nvim-telescope.nvim`, no `nvim-telescope/telescope.nvim`.
  ---@type table<string, fun()>
  config = {},

  --- Carga diferida. El valor es el evento de `User` que la dispara.
  --- Ejemplo: `["lazy.nvim"] = "VeryLazy"` carga en el primer `User VeryLazy`.
  ---@type table<string, string>
  lazy = {},
}