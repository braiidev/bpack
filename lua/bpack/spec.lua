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

  -- ── Herramientas, no plugins ─────────────────────────────────────────────
  -- Los binarios que necesitan los servidores de lenguaje y los formateadores.
  -- Vive en el mismo archivo que `plugins` a propósito: es un solo lugar donde
  -- ver qué administra bpack, aunque el mecanismo sea otro (npm o un release).
  --
  -- Por qué no usamos lo que hay en `/usr/bin` o en el npm global: la matriz de
  -- `lua/lang/` tiene que apuntar a una ruta que nosotros controlamos, o el
  -- comportamiento de Neovim depende de lo que el sistema tenga instalado.
  -- Se instalan en `~/.local/opt/bpack-tools/` y se reachan por un shim en
  -- `~/.local/bin`, que ya está en el PATH.
  --
  -- `kind` decide el mecanismo:
  --   `npm`     → `npm install --prefix`, sin `-g`. No toca el sistema.
  --   `release` → un artefacto de un release de GitHub para esta plataforma.
  --
  -- `version` va pineado por la misma razón que los plugins: para que dos
  -- máquinas con la misma config se comporten igual.
  --
  -- La clave es el nombre del ejecutable, no del paquete: `ruff`, no
  -- `astral-sh/ruff`. Es lo que `lua/lang/` busca.
  ---@type table<string, table>
  tools = {
    ruff = {
      kind = "release",
      version = "0.14.6",
      desc = "linter y formateador de Python",
      -- Los assets de ruff llevan el triple plataforma en el nombre.
      asset = "ruff-%s.tar.gz",
      targets = { ["linux-x86_64"] = "x86_64-unknown-linux-gnu", ["linux-aarch64"] = "aarch64-unknown-linux-gnu", ["darwin-x86_64"] = "x86_64-apple-darwin", ["darwin-aarch64"] = "aarch64-apple-darwin" },
      url = "https://github.com/astral-sh/ruff/releases/download/%s/",
      -- Adentro del tarball el binario cuelga de un subdirectorio con el
      -- nombre del release. Es lo que hace `tar` y nada más.
      inner = "ruff",
      bin = "ruff",
    },
    stylelint = {
      kind = "npm",
      version = "16.26.0",
      pkg = "stylelint",
      desc = "linter de CSS",
    },
  },
}