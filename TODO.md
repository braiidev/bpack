# TODO

Task = 1 commit atomico. El detalle real vive en `git log` y en el tag del commit.
`PLAN.md` es scratch por task y esta gitignorado: es la fuente de verdad de la
fase en curso, este archivo es el indice de trabajo.

## Doing

- [ ] `tests/` de la config: sandbox con `BPACK_TOOLS_ROOT`, y los casos de
      install.sh (idempotencia, cancelacion, verificacion que falla) - v0.13

## Done

- [x] Bootstrap del repo: `git init`, `.gitignore` minimo, commit inicial - v0.1
- [x] Esqueleto del proyecto: `AGENTS.md`, `TODO.md` y `PLAN.md` de la fase 0 - v0.2
- [x] `init.lua` + `bpack/init.lua`: guarda de 0.12, `pcall` sobre todo - v0.3
- [x] `core/`: options y autocmds base, sin plugins - v0.4
- [x] `keys.lua` + `keymap.lua` + `:Bpack keys` autogenerado - v0.5
- [x] `theme.lua` + port de `flatline` + persistencia en `state.json` - v0.6
- [x] `spec.lua` + wrapper de `vim.pack` + `:Bpack sync/add/del/update/list/log` - v0.7
- [x] `doctor.lua` + `:Bpack doctor` - v0.8
- [x] `scripts/bpack` + `:Bpack selfupdate` con rollback - v0.9
- [x] Replan: 4 fases, toolchain antes de los lenguajes, IDE completo - v0.10
- [x] `spec.tools` + `:Bpack install`: prefijo controlado, shims, y el `!` del
      dispatcher arreglado - v0.11
- [x] `install.sh` interactivo: preflight, reporte, verificacion previa, y el
      intercambio con backup - v0.12

## Fase 0 — el gestor se vuelve capaz de sustentar todo

La toolchain va **antes** que los lenguajes: `lua/lang/python.lua` tiene que
apuntar al ruff que instala bpack, no al que haya en `/usr/bin`. Construir los
lenguajes primero contra el sistema obliga a reescribirlos todos después.

- [x] `spec.tools` + `:Bpack install`: prefijo controlado en
      `~/.local/opt/bpack-tools/` y shims en `~/.local/bin` - v0.11
- [ ] `install.sh` interactivo: reporta la version de Neovim, lista lo que falta,
      pregunta, y hace `install` + `sync`. Clona al lado y verifica antes de
      intercambiar - v0.12
- [ ] `tests/` de la config + gate de arranque limpio. Los casos de install.sh
      (idempotencia, cancelacion, verificacion que falla) van aca. Y el doctor
      reporta `__no_start_dir__` como error siendo un directorio vacio que
      `vim.pack` ignora: medido, no rompe el arranque. O se corrige la
      comprobacion o el texto de `AGENTS.md`, que decia que el motor llama
      `error()` - v0.13

## Fase intermedia — el set de plugins, instalado por bpack

Primera prueba real del gestor: los plugins entran por el mismo camino que va a
usar el usuario, no a mano. Los siete del orden de prioridad.

- [ ] `nvim-lspconfig` cargado por runtimepath, **sin** `require("lspconfig")`.
      Y de paso: el spec no normaliza `user/repo` a URL. Escrito a mano,
      `folke/plenary.nvim` falla con `repository does not exist`; `:Bpack add` si
      lo hace. Es la primera task que mete un plugin, asi que es donde se
      arregla - v0.14
- [ ] `nvim-treesitter` + el bloque de parsers de los 7 lenguajes - v0.15
- [ ] `conform.nvim` - v0.16
- [ ] `nvim-cmp` + `LuaSnip` + `friendly-snippets` (bloque inseparable) - v0.17
- [ ] `telescope.nvim` + `plenary.nvim` - v0.18
- [ ] `lualine.nvim` + `nvim-web-devicons`, con statusline condicional - v0.19
- [ ] El set entero: sync limpio, doctor verde, sin huerfanos - v0.20

## Fase 1 — matriz de lenguajes

Un commit por idioma, cada uno con lsp + treesitter + conform + capabilities.
Los 7 servidores ya estan instalados en el sistema; en esta fase pasan a
apuntar a los que instala bpack.

- [ ] Esqueleto de `lua/lang/` con registro declarativo y dispatch por filetype - v0.21
- [ ] `lua.lua` - v0.22
- [ ] `python.lua`: pyright + ruff - v0.23
- [ ] `javascript.lua` + `typescript.lua`: ts_ls + prettier + eslint - v0.24
- [ ] `html.lua` + `css.lua`: html + cssls + emmet + stylelint - v0.25
- [ ] `markdown.lua`: markdownls + prettier - v0.26
- [ ] `bash.lua`: bashls + shfmt + shellcheck - v0.27
- [ ] De apoyo: `json.lua` + `yaml.lua` - v0.28

## Fase 2 — IDE: las cualidades que faltaban

De las 15 de un IDE, el plan viejo cubria 9. Estas son las 6 que faltaban. Los
keymaps se definien al final, cuando bpack funcione entero.

- [ ] Simbolos del workspace + call hierarchy + type definition - v0.29
- [ ] Code actions con picker (las de LSP, no las de Neovim) - v0.30
- [ ] Organize imports por lenguaje - v0.31
- [ ] Textobjects de treesitter - v0.32
- [ ] Diagnostics de workspace: `pyright --project`, `tsc --noEmit`, con los
      resultados metidos en el buffer - v0.33
- [ ] Extract e inline (refactor mecanico) - v0.34
- [ ] Comportamientos: keymaps LSP, la regla de contexto statusline/dashboard,
      y el reparto de atajos - v0.35

## Fase 3 — extensiones

- [ ] `gitsigns.nvim` + `fugitive` (no esta en disco, hay que bajarlo) - v0.36
- [ ] `nvim-tree.lua` con render de estado de git - v0.37
- [ ] `alpha-nvim` como dashboard, solo al abrir sin ruta - v0.38
- [ ] Terminal, conservando `<leader>t*` de la config vieja - v0.39
- [ ] `:Bpack test` con dispatch por filetype - v0.40
- [ ] DAP con adapters por lenguaje - v0.41

## Fase 4 — portabilidad y el swap

- [ ] Prueba en `HOME` temporal, instalacion de cero de verdad - v0.42
- [ ] `MIGRATION.md` con el procedimiento para las otras maquinas - v0.43
- [ ] Swap de `~/.config/nvim` con backup previo, y borrado de lo viejo:
      `/usr/bin/lua-language-server`, `~/.local/bin/pyright` y los 12 paquetes de
      `~/.npm-global/lib/node_modules/` - v0.44

## Descartado

- **lazy.nvim**: su `uninstall` deja el directorio en disco como mugre.
  `vim.pack.del` (`pack.lua:1374`) hace `vim.fs.rm(p.path, {recursive=true})`
  y borra de verdad.
- **Motor de plugins 100% propio**: obliga a reimplementar install, lockfile y
  rollback, y a perder `del`.
- **Vender los plugins en el repo** (`pack/` dentro del config): +113M y cada
  update es un merge contra upstream. Los plugins viven en el data dir; el
  lockfile si se commitea.
- **Sentinel `start_path` en el pack dir**: fue el exacto motivo por el que la
  config vieja no arranca. Ver `PLAN.md`, decision 3.
- **Que `install.sh` edite el `.zshrc`**: sumar `~/.local/opt/bpack-tools/bin` al
  PATH obliga a tocar la shell del usuario. Los shims en `~/.local/bin`, que ya
  esta en el PATH, resuelven lo mismo sin invadir nada.
- **Borrar `~/.config/nvim` en la instalacion**: se mueve a un backup con
  timestamp. Ademas el instalador viejo dejaba una ventana sin config entre el
  `mv` y el `git clone`; el nuevo clona al lado, verifica que arranque, y recien
  ahi intercambia. Si algo falla antes, no se toco nada.
