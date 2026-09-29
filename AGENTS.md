# bpack

Configuracion de Neovim. El repo **es** la configuracion: no hay build step, lo
que se commitea es lo que Neovim ejecuta.

Se developea en `~/Dev/_nvim` y `install.sh` lo deja montado en
`~/.config/nvim`.

## Requisitos

- **Neovim 0.12+** (obligatorio: el gestor usa `vim.pack`, que no existe antes)
- `git`
- `node` + `npm` (LSP de JS/TS, prettier, emmet) — a partir de la fase 3

## Comandos

Todo pasa por un comando con subcomando:

```
:Bpack sync            # spec <-> disco <-> lock, idempotente
:Bpack add user/repo   # clona y agrega al spec
:Bpack del name        # borra el directorio del plugin
:Bpack update [name]   # con verificacion de arranque y rollback
:Bpack list            # plugins instalados
:Bpack log name [n]    # ultimos commits
:Bpack search query    # busca en GitHub
:Bpack keys [patron]   # keymaps, autogenerado desde lua/bpack/keys.lua
:Bpack theme [nombre]  # cambia el tema y lo persiste
:Bpack theme list      # temas disponibles
:Bpack doctor          # diagnostico
:Bpack selfupdate      # git pull del repo-config + resync
:Bpack reload          # recarga lo nuestro sin re-sourcer init.lua
```

Linea de comandos, para el instalador y para la shell:

```bash
scripts/bpack --setup      # instalacion de cero
scripts/bpack --sync
scripts/bpack --doctor
scripts/bpack --version
```

## Como se trabaja

Task = 1 commit atomico, version `v0.N`, tag en el commit. `TODO.md` es el
indice de trabajo y `PLAN.md` la fuente de verdad de la fase en curso.

## Verificar

El gate de cada task es que Neovim arranque con esta config:

```bash
nvim --headless -u ./init.lua -c 'q'
```

`tests/run.sh` corre los tests de la config:

```bash
tests/run.sh
```

## Estructura

| Path | Que es |
|---|---|
| `init.lua` | 3 lineas |
| `lua/bpack/` | el gestor: spec, keys, theme, cmd, doctor, state |
| `lua/core/` | opciones y autocmds base, sin plugins |
| `lua/lang/` | matriz IDE, un archivo por lenguaje |
| `lua/ui/ git/ term/ test/ dap/` | features |
| `colors/` | `flatline` |
| `scripts/` | CLI `bpack` + toolchain |
| `tests/` | tests de la config |

## Regla de oro del gestor

**No se escribe nunca dentro del pack dir** (`stdpath('data')/site/pack/core/opt`).
Es territorio exclusivo de `vim.pack`, y el motor llama `error()` si encuentra
ahi algo que no sea un clon valido de git — eso baja Neovim entero.
