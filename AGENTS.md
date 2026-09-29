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
| `install.sh` | instalador de cero: preflight, reporte, pregunta, verifica, y recién ahi intercambia |
| `lua/bpack/` | el gestor: spec, engine, cmd, keys, theme, doctor, selfupdate, toolchain, state |
| `lua/core/` | opciones y autocmds base, sin plugins |
| `lua/lang/` | matriz IDE, un archivo por lenguaje |
| `lua/ui/ git/ term/ test/ dap/` | features |
| `colors/` | `flatline` |
| `scripts/` | CLI `bpack` |
| `tests/` | tests de la config |

## Como se instala

`install.sh` (o `scripts/bpack --setup`, que delega en él) hace 8 pasos, y el
orden es el punto: **verifica antes de intercambiar**. Corre la config nueva con
`XDG_*` temporales, mira el log de arranque, y sólo si está limpia mueve la config
actual a `~/.config/nvim.bak.<timestamp>`. El instalador viejo hacía `mv` y
después `clone`, y entre los dos pasos no había config en su lugar.

No mira el exit code de Neovim para decidir si la config anda, por la misma
razón que el doctor: `util.protect` deja el arranque en 0 aunque un módulo esté
roto. Busca `ERROR en` en el log.

Es idempotente: si el stub ya está y apunta al mismo repo, no mueve nada.

**El montaje es un stub, no un symlink.** `~/.config/nvim/init.lua` son tres
líneas que hacen `dofile` de `init.lua` del repo. La razón está medida:
`vim.pack` escribe el lock en `stdpath('config')`, o sea adentro de
`~/.config/nvim`. Si ese directorio fuera el repo, el lock aterrizaría en el
árbol de git, que quedaría sucio, y `:Bpack selfupdate` aborta por exigir árbol
limpio. Con el stub, el lock queda en el config dir y el repo no se toca.

## Regla de oro del gestor

**No se escribe nunca dentro del pack dir** (`stdpath('data')/site/pack/core/opt`).
Es territorio exclusivo de `vim.pack`. Si encuentra ahi algo que no sea un clon
valido de git, el sync falla con `fatal: not a git repository`
(`pack.lua:251`). Como la llamada al motor va dentro de `util.protect`, Neovim
**arranca igual** y el sync simplemente no pasa: el fallo se ve en el log, no en
la pantalla.

Lo que hace parecer inocuo a esto es que el pack dir sólo se camina cuando el
spec tiene plugins. Con el spec vacío `vim.pack` no mira adentro y un directorio
suelto ahí pasa desapercibido. Y un clon git que bpack no declara **no molesta**:
medido, `vim.pack` lo ignora sin quejarse. Lo único que rompe es una entrada que
no es clon — en esta maquina, `__no_start_dir__`, dejado por la config anterior.

Por eso la primera task que mete un plugin tiene que borrar `__no_start_dir__`
antes del primer sync.
