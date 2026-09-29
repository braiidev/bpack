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
:Bpack selfupdate!     # idem, sin probar la config nueva en un proceso hijo
```

La lista de arriba es la real. Las dos siguientes **no existen todavia** y estan
aca para no olvidarlas; si las implementas, sacales la marca:

```
:Bpack search query    # busca en GitHub          (no implementado)
:Bpack reload          # recarga lo nuestro       (no implementado)
```

`selfupdate` exige el árbol limpio (si no, aborta: el rollback descarta lo que no
esté commiteado), y después de traer la config nueva la **arranca en un proceso
hijo** para ver si funciona. Si no, vuelve al commit anterior con
`git reset --hard`. La salud se juzga por el log, no por el exit code: nuestra
config se protege con `util.protect`, así que un módulo roto deja el arranque en
exit 0. Cuando el hijo no dice nada útil no se revierte a ciegas: avisa y deja el
comando de vuelta atrás a mano.

Linea de comandos, para el instalador y para la shell:

```bash
scripts/bpack --setup      # instalacion de cero (delega en install.sh)
scripts/bpack --sync
scripts/bpack --doctor     # sale por stdout; exit 1 si hay errores
scripts/bpack --selfupdate
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
