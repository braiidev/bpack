#!/usr/bin/env bash
# Instalador de cero de bpack.
#
# Qué hace y por qué en este orden:
#
# 1. Verifica que se pueda seguir. Si Neovim es viejo o no estamos en un repo
#    bpack, no hay nada que instalar.
# 2. Muestra qué va a hacer y qué falta. Nada de surprises.
# 3. Pregunta. Sin respuesta, no toca el disco.
# 4. Instala las herramientas y sincroniza los plugins.
# 5. **Verifica antes de intercambiar.** Corre la config candidata con XDG
#    temporales y mira el log de arranque. Si hay errores, aborta y la config
#    actual queda como estaba.
# 6. Sólo entonces mueve la config vieja a un backup con timestamp y escribe el
#    stub.
#
# El paso 5 existe porque el instalador viejo hacía `mv ~/.config/nvim <backup>`
# y después `git clone` al hueco. Entre los dos pasos no había config en su
# lugar: si el clone fallaba, el usuario se quedaba sin editor. Acá el
# intercambio es la última cosa que pasa, y sólo si ya sabemos que anda.

set -euo pipefail

NVIM_MIN="0.12.0"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; OFF=$'\033[0m'
[[ -t 1 ]] || { BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; OFF=""; }

info() { printf '%s\n' "$*"; }
step() { printf '%s==>%s %s\n' "$BOLD" "$OFF" "$*"; }
ok()   { printf '  %sok%s   %s\n' "$GREEN" "$OFF" "$*"; }
warn() { printf '  %savis%s %s\n' "$YELLOW" "$OFF" "$*"; }
bad()  { printf '  %sfall%s %s\n' "$RED" "$OFF" "$*" >&2; }
die()  { bad "$*"; exit 1; }

# ── 1. Preflight ─────────────────────────────────────────────────────────────
step "Preflight"

command -v nvim >/dev/null 2>&1 || die "no encuentro 'nvim' en el PATH"
NVIM_VERSION="$(nvim --version | head -1 | awk '{print $2}')"
info "  Neovim $NVIM_VERSION"

# Comparación de versiones sin `sort -V`, que no está en todos los shells.
version_lt() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" != "$2" ]]
}
if version_lt "$NVIM_VERSION" "$NVIM_MIN"; then
  die "hace falta Neovim $NVIM_MIN o superior (tenés $NVIM_VERSION). El gestor usa vim.pack, que no existe antes."
fi
ok "versión suficiente"

[[ -f "$REPO/lua/bpack/init.lua" ]] || die "esto no parece un repo de bpack: falta lua/bpack/init.lua"
ok "repo bpack en $REPO"

if [[ -d "$REPO/.git" ]]; then
  if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
    warn "el repo tiene cambios sin commitear. Se instala igual, pero :Bpack selfupdate va a abortar hasta que los commitees."
  else
    ok "árbol limpio"
  fi
fi

# ── Estado actual ────────────────────────────────────────────────────────────
STUB_MARKER="bpack: stub"
MOUNTED=0
BACKUP=""
if [[ -f "$CONFIG_DIR/init.lua" ]]; then
  if grep -q "$STUB_MARKER" "$CONFIG_DIR/init.lua" 2>/dev/null; then
    MOUNTED=1
    ok "ya está montado: $CONFIG_DIR/init.lua es un stub de bpack"
  else
    # `|| true` es obligatorio: con `pipefail`, un `ls` que no encuentra nada
    # sale con error y `set -e` aborta el instalador entero. Un backup previo
    # inexistente es el caso normal en una primera instalación, no un fallo.
    BACKUP="$(ls -1dt "$CONFIG_DIR".bak.* 2>/dev/null | head -1 || true)"
    if [[ -n "$BACKUP" ]]; then
      info "  hay un backup previo: $(basename "$BACKUP")"
    fi
    warn "$CONFIG_DIR/init.lua no es un stub de bpack: se va a reemplazar (la config actual va a un backup)"
  fi
else
  warn "no hay config en $CONFIG_DIR todavía"
fi

# ── 2. Reporte ───────────────────────────────────────────────────────────────
step "Qué hace falta instalar"

MISSING_TOOLS=0
if command -v nvim >/dev/null 2>&1; then
  # Se imprime con un marcador, no el número pelado: `tr -dc '0-9'` sobre toda la
  # salida se lleva los dígitos de cualquier otro mensaje y da un número
  # inventado. Con el marcador sólo se lee lo que se imprimió a propósito.
  #
  # `2>&1` porque en headless el `print` de Lua sale por stderr, no por stdout.
  # Con `2>/dev/null` el comando no devuelve nada y el conteo queda en 0, que es
  # justo el número que miente diciendo "no falta nada".
  MISSING_TOOLS="$(nvim --headless -u "$REPO/init.lua" \
    -c 'lua local n=0 for _,e in ipairs(require("bpack.toolchain").status()) do if e.state=="falta" or e.state=="sin shim" then n=n+1 end end print("BPACK_FALTAN:"..n)' \
    -c 'qa!' 2>&1 | sed -n 's/^BPACK_FALTAN:\([0-9]*\).*/\1/p' | head -1 || true)"
  MISSING_TOOLS="${MISSING_TOOLS:-0}"
  if ! [[ "$MISSING_TOOLS" =~ ^[0-9]+$ ]]; then
    MISSING_TOOLS="?"
  fi
fi
PLUGIN_COUNT="$(grep -cE '^\s+"https?://' "$REPO/lua/bpack/spec.lua" 2>/dev/null || true)"
PLUGIN_COUNT="${PLUGIN_COUNT:-0}"
PLUGIN_COUNT="${PLUGIN_COUNT:-0}"

info "  herramientas faltantes: $MISSING_TOOLS"
info "  plugins declarados:     $PLUGIN_COUNT"
info "  destino:                $CONFIG_DIR"
info "  $DIM(origen: $REPO)$OFF"

if (( MISSING_TOOLS == 0 && PLUGIN_COUNT == 0 )); then
  warn "no hay nada que instalar. ¿Querés sólo montar la config?"
fi

# ── 3. Pregunta ──────────────────────────────────────────────────────────────
step "Confirmación"
info "  La config actual se mueve a $CONFIG_DIR.bak.<timestamp> y queda reversible."
read -r -p "  ¿Sigo? [s/N] " reply
case "${reply:-}" in
  [sSyY]*) ;;
  *) info "  cancelado. No toqué nada."; exit 0 ;;
esac

# ── 4. Herramientas y plugins ────────────────────────────────────────────────
step "Herramientas"
# BPACK_TOOLS_ROOT no se toca: se hereda del que llama. Así los tests pueden
# aislar la instalación y el usuario tiene el home real. (Ponerlo vacío sería
# peor que no ponerlo: en Lua la cadena vacía es truthy y el prefijo caería en
# `/.local/opt/bpack-tools`.)
if nvim --headless -u "$REPO/init.lua" -c 'Bpack install!' -c 'qa!' 2>&1 | sed 's/^/  /'; then
  ok "herramientas listas"
else
  warn "algunas herramientas no se pudieron instalar; sigo igual (ver el log de bpack)"
fi

step "Plugins"
if nvim --headless -u "$REPO/init.lua" -c 'Bpack sync' -c 'qa!' 2>&1 | sed 's/^/  /'; then
  ok "plugins sincronizados"
else
  warn "el sync falló. Sigo igual: la verificación de abajo va a decir si importa."
fi

# ── 5. Verificar ANTES de intercambiar ───────────────────────────────────────
step "Verificación previa (sin tocar tu config)"

VERIFY="$(mktemp -d "${TMPDIR:-/tmp}/bpack-verify.XXXXXX")"
trap 'rm -rf "$VERIFY"' EXIT

# Se corre la config del repo con XDG temporales. Si el arranque tiene errores,
# se aborta acá: todavía no movimos nada.
set +e
env XDG_CONFIG_HOME="$VERIFY/cfg" \
    XDG_DATA_HOME="$VERIFY/data" \
    XDG_STATE_HOME="$VERIFY/state" \
    XDG_CACHE_HOME="$VERIFY/cache" \
    BPACK_TOOLS_ROOT="$VERIFY/home" \
    nvim --headless -u "$REPO/init.lua" \
      -c 'lua vim.defer_fn(function() vim.cmd("qa!") end, 120)' 2>/dev/null
env XDG_CONFIG_HOME="$VERIFY/cfg" \
    XDG_DATA_HOME="$VERIFY/data" \
    XDG_STATE_HOME="$VERIFY/state" \
    XDG_CACHE_HOME="$VERIFY/cache" \
    BPACK_TOOLS_ROOT="$VERIFY/home" \
    nvim --headless -u "$REPO/init.lua" -c 'Bpack doctor' -c 'qa!' >"$VERIFY/doctor.txt" 2>&1
set -e

# El arranque no puede depender del exit code: `util.protect` deja el arranque
# en exit 0 aunque un módulo esté roto. Por eso el fallo se busca en el log.
STARTUP_ERRORS=0
if [[ -f "$VERIFY/state/nvim/bpack/bpack.log" ]]; then
  STARTUP_ERRORS="$(grep -c 'ERROR en' "$VERIFY/state/nvim/bpack/bpack.log" || true)"
fi
STARTUP_ERRORS="${STARTUP_ERRORS:-0}"

if (( STARTUP_ERRORS > 0 )); then
  bad "la config nueva tiene $STARTUP_ERRORS error(es) de arranque. No toco tu config actual."
  grep 'ERROR en' "$VERIFY/state/nvim/bpack/bpack.log" | sed 's/^/    /' >&2
  die "resolvé eso y volvé a correr install.sh"
fi
ok "arranque sin errores"

if grep -qE '^1 error|^[2-9][0-9]* error' "$VERIFY/doctor.txt" 2>/dev/null; then
  warn "el doctor reporta errores (revisá el log); sigo porque el arranque está limpio"
fi

# ── 6. Intercambiar ──────────────────────────────────────────────────────────
step "Intercambio"

# Escribe el stub. Aparte para poder llamarla de dos ramas: la primera
# instalación y el caso de que el stub apunte a otro repo.
write_stub() {
  mkdir -p "$CONFIG_DIR"
  # El heredoc va entrecomillado a propósito. Sin comillas, los backticks de los
  # comentarios Lua se ejecutan como command substitution, y el instalador
  # escribe en el stub la salida del comando en vez del comentario. Por eso
  # {{REPO}} y {{MARKER}} se inyectan después con sed, y no por expansión.
  cat > "$CONFIG_DIR/init.lua" <<'STUB'
-- {{MARKER}} -- generado por install.sh. Editá la config en el repo:
--   {{REPO}}
--
-- Este archivo existe sólo para que Neovim encuentre la config: la real está en
-- el repo de desarrollo y acá hay un puntero.
--
-- Por qué un stub y no un symlink del directorio: vim.pack escribe el lock en
-- stdpath('config'), o sea adentro de este directorio. Si el directorio fuera el
-- repo, el lock aterrizaría en el árbol de git, que quedaría sucio, y
-- :Bpack selfupdate aborta por exigir árbol limpio. Con el stub, el lock queda
-- acá y el repo no se toca.
dofile("{{REPO}}/init.lua")
STUB
  # El marcador también va por placeholder: con el heredoc entrecomillado, una
  # variable $STUB_MARKER se escribiría literal y el stub no se reconocería al
  # correr install.sh de nuevo, que es justamente lo que rompe la idempotencia.
  sed -i -e "s|{{REPO}}|$REPO|g" -e "s|{{MARKER}}|$STUB_MARKER|g" "$CONFIG_DIR/init.lua"
  ok "stub escrito en $CONFIG_DIR/init.lua"
}

# Si ya está montado, no se mueve nada. Correr el instalador dos veces tiene que
# ser inocuo: sin este `if`, la segunda corrida movía el stub que la primera
# acababa de escribir a un backup nuevo y lo reescribía, dejando un backup
# espurio por corrida.
if (( MOUNTED )); then
  if grep -qF "$REPO/init.lua" "$CONFIG_DIR/init.lua"; then
    ok "ya montado y apunta a este repo: no muevo nada"
  else
    warn "el stub apunta a otro repo; lo reescribo sin tocar backups"
    write_stub
  fi
else
  if [[ -e "$CONFIG_DIR" ]]; then
    BACKUP="$CONFIG_DIR.bak.$(date +%Y%m%d-%H%M%S)"
    info "  muevo la config actual a $(basename "$BACKUP")"
    mv "$CONFIG_DIR" "$BACKUP"
    ok "backup en $BACKUP"
  fi
  write_stub
fi

# ── 7. Confirmación final ────────────────────────────────────────────────────
step "Verificación final (con tu config de verdad)"

set +e
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}" nvim --headless -c 'qa!' >/dev/null 2>&1
set -e

REAL_LOG="$XDG_STATE_HOME/nvim/bpack/bpack.log"
[[ -n "${XDG_STATE_HOME:-}" ]] || REAL_LOG="$HOME/.local/state/nvim/bpack/bpack.log"
if [[ -f "$REAL_LOG" ]]; then
  RECENT_ERRORS="$(tail -20 "$REAL_LOG" | grep -c 'ERROR en' || true)"
  RECENT_ERRORS="${RECENT_ERRORS:-0}"
  if (( RECENT_ERRORS > 0 )); then
    warn "el último arranque con la config nueva registró errores. Mirá:"
    tail -20 "$REAL_LOG" | grep 'ERROR en' | sed 's/^/    /'
  else
    ok "arranque limpio con la config nueva"
  fi
else
  warn "no encontré el log en $REAL_LOG"
fi

info ""
ok "listo. Abrí nvim."
if [[ -n "$BACKUP" ]]; then
  info "  $DIM(Config anterior en $BACKUP. Para volver atrás:)$OFF"
  info "  $DIM  mv '$BACKUP' '$CONFIG_DIR'$OFF"
fi
