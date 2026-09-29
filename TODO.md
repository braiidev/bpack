# TODO

Task = 1 commit atomico. El detalle real vive en `git log` y en el tag del commit.
`PLAN.md` es scratch por task y esta gitignorado: es la fuente de verdad de la
fase en curso, este archivo es el indice de trabajo.

## Doing

- [x] `theme.lua` + port de `flatline` + persistencia en `state.json` - v0.6

## Done

- [x] Bootstrap del repo: `git init`, `.gitignore` minimo, commit inicial - v0.1
- [x] Esqueleto del proyecto: `AGENTS.md`, `TODO.md` y `PLAN.md` de la fase 0 - v0.2
- [x] `init.lua` + `bpack/init.lua`: guarda de 0.12, `pcall` sobre todo - v0.3
- [x] `core/`: options y autocmds base, sin plugins - v0.4
- [x] `keys.lua` + `keymap.lua` + `:Bpack keys` autogenerado - v0.5

## Next — Fase 0: cimientos de `bpack`

- [x] `init.lua` + `bpack/init.lua`: guarda de 0.12, `pcall` sobre todo - v0.3
- [x] `core/`: options y autocmds base, sin plugins - v0.4
- [x] `keys.lua` + `keymap.lua` + `:Bpack keys` autogenerado - v0.5
- [x] `theme.lua` + port de `flatline` + persistencia en `state.json` - v0.6
- [ ] `spec.lua` + wrapper de `vim.pack` + `:Bpack sync/add/del/update/list/log` - v0.7
- [ ] `doctor.lua` + `:Bpack doctor` - v0.8
- [ ] `scripts/bpack` + `:Bpack selfupdate` con rollback - v0.9
- [ ] `install.sh` idempotente - v0.10
- [ ] `tests/` de la config + gate de arranque limpio - v0.11

## Next — Fase 1: matriz de lenguajes

- [ ] Esqueleto de `lua/lang/` con el registro declarativo y el dispatch por
      filetype - v0.12
- [ ] `python.lua`: pyright + ruff + pytest + debugpy - v0.13
- [ ] `typescript.lua` + `javascript.lua`: ts_ls + prettier + eslint_d + vitest - v0.14
- [ ] `html.lua` + `css.lua`: html/cssls + emmet + prettier - v0.15
- [ ] `bash.lua`: bashls + shfmt + shellcheck + bats - v0.16
- [ ] `markdown.lua`: marksman + prettier + markdownlint - v0.17
- [ ] De apoyo: `lua.lua`, `json.lua`, `yaml.lua` - v0.18

## Next — Fase 2: IDE

- [ ] `cmp` + luasnip con la fuente propia de LSP - v0.19
- [ ] `conform` por lenguaje + `ruff` reemplaza `black` - v0.20
- [ ] treesitter sin `ensure_installed` (install por lock) - v0.21
- [ ] 13 keymaps LSP + `[d` / `]d` + `gr` - v0.22
- [ ] Opciones base: `completeopt`, `inccommand=split`, `hidden`, `scrolloff` - v0.23

## Next — Fase 3: git, terminal, tests, debug

- [ ] `gitsigns` + `fugitive` - v0.24
- [ ] Terminal: conserva `<leader>t*` de la config vieja, con `%` expandido - v0.25
- [ ] `:Bpack test` con dispatch por filetype - v0.26
- [ ] DAP con adapters por lenguaje - v0.27
- [ ] `scripts/toolchain.sh`: binarios en `~/.local/opt/bpack-tools/` - v0.28

## Next — Fase 4: portabilidad

- [ ] Prueba en `HOME` temporal, instalacion de cero - v0.29
- [ ] `MIGRATION.md` con el procedimiento de las otras maquinas - v0.30
- [ ] Reemplazo de `~/.config/nvim`, con backup previo - v0.31

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
