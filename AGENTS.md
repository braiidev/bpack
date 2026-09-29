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
:Bpack install [name]  # instala las herramientas de la toolchain
:Bpack install!        # idem, sin preguntar (lo usan install.sh y los tests)
```

El `!` va siempre pegado al subcomando, como en `:w!`: `:Bpack update! telescope`,
`:Bpack install!`. Sin `!` se pregunta antes de tocar el disco, y en headless la
respuesta por defecto es "No".

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

## Toolchain

`spec.tools` declara los binarios que necesitan los servidores de lenguaje y los
formateadores, con dos mecánicas: `release` (un artefacto de GitHub para la
plataforma) y `npm` (`npm install --prefix`, **sin** `-g`).

```
~/.local/opt/bpack-tools/     # los binarios reales
~/.local/bin/                 # un shim por herramienta
```

El shim es la parte que evita editar el `.zshrc`: son tres líneas con `exec` que
apuntan al binario real, y `~/.local/bin` ya está en el PATH. Por eso `ruff`
funciona en Neovim y en la terminal, y bpack no toca la shell del usuario.

`BPACK_TOOLS_ROOT` mueve la raíz entera. Existe por una razón medida: **el
Neovim de snap ignora `HOME`** — con `HOME=/tmp/x`, `vim.env.HOME` sigue valiendo
el home real. `XDG_*` sí lo respeta, pero `~/.local/bin` no es una ruta XDG. Sin
este override no hay forma de probar una instalación sin escribir en el home del
usuario, que es justo lo que hay que evitar antes de confiar en el comando.

"Instalada" significa binario **y** shim. Si sólo está el binario, el estado es
`sin shim` y `:Bpack install` lo repara; reporting sólo el binario haría que
`install` diga "ya está" y el usuario descubra que la herramienta no está en el
PATH recién cuando la invoca.

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
| `lua/bpack/` | el gestor: spec, engine, cmd, keys, theme, doctor, selfupdate, toolchain, state |
| `lua/core/` | opciones y autocmds base, sin plugins |
| `lua/lang/` | matriz IDE, un archivo por lenguaje |
| `lua/ui/ git/ term/ test/ dap/` | features |
| `colors/` | `flatline` |
| `scripts/` | CLI `bpack` |
| `tests/` | tests de la config |

## Regla de oro del gestor

**No se escribe nunca dentro del pack dir** (`stdpath('data')/site/pack/core/opt`).
Es territorio exclusivo de `vim.pack`, y el motor llama `error()` si encuentra
ahi algo que no sea un clon valido de git — eso baja Neovim entero.
