#!/usr/bin/env bash
# Tests de la config.
#
# Regla que gobierna todo el archivo: **ningún test toca el home real**. Cada caso
# se corre con `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`,
# `XDG_CACHE_HOME` y `BPACK_TOOLS_ROOT` apuntando a un sandbox propio.
#
# El motivo es concreto: `vim.pack` escribe el lock en `stdpath('config')` y los
# plugins en `stdpath('data')`. Un test que se salte el sandbox no está probando
# la config, está probando la máquina de quien lo corre.
#
# Tampoco se baja nada de la red. Los casos de `install.sh` pre-siembran las
# herramientas en el sandbox, así que corren en segundos y sin conexión. Los
# tests que sí necesitan red van aparte y se activan con BPACK_TEST_NETWORK=1,
# porque un test que depende de que GitHub esté arriba no es un test, es una
# apuesta.
#
#   tests/run.sh                 # suite hermética
#   BPACK_TEST_NETWORK=1 tests/run.sh   # suma los que descargan

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bpack-tests.XXXXXX")"
NETWORK="${BPACK_TEST_NETWORK:-0}"

PASS=0
FAIL=0
CURRENT=""

BOLD=$'\033[1m'; GREEN=$'\033[32m'; RED=$'\033[31m'; YELLOW=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
[[ -t 1 ]] || { BOLD=""; GREEN=""; RED=""; YELLOW=""; DIM=""; OFF=""; }

# ── Sale de un test ──────────────────────────────────────────────────────────
# Sin `set -e`: un test que falla tiene que *reportar*, no matar la corrida y
# dejar los casos siguientes sin ejecutar. El que decide si algo está roto es
# el código de salida final.
set -uo pipefail

# ── Sandboxes ────────────────────────────────────────────────────────────────
# Uno por caso. Se limpian al final con `find -delete` y no con `rm -rf`: además
# de que `find -delete` no pide confirmación, no hay forma de que un `rm -rf`
# con variable mal formada borre algo fuera del sandbox.
sandbox() {
  local name="$1"
  local d="$SANDBOX_ROOT/$name"
  mkdir -p "$d/home" "$d/cfg" "$d/data" "$d/state" "$d/cache"
  printf '%s' "$d"
}

# Entorno aislado. Se exporta, no se pasa por argumento, porque hay que invocar
# nvim de varias formas distintas (con -u, sin -u, con `| bash`) y repetir la
# lista de variables en cada una es la forma segura de olvidarse una.
isolate() {
  local d="$1"
  export XDG_CONFIG_HOME="$d/cfg"
  export XDG_DATA_HOME="$d/data"
  export XDG_STATE_HOME="$d/state"
  export XDG_CACHE_HOME="$d/cache"
  export BPACK_TOOLS_ROOT="$d/home"
}

# Pre-siembra las herramientas declaradas en el spec con archivos falsos.
#
# Es lo que hace que la suite no dependa de la red: `status()` ve binario y shim,
# así que `Bpack install!` no tiene nada que hacer. Lo que se prueba es la
# *lógica* de install.sh, no la descarga — esa se probó una vez a mano, y se
# vuelve a probar con BPACK_TEST_NETWORK=1.
seed_tools() {
  local d="$1"
  local prefix="$d/home/.local/opt/bpack-tools"
  local bin="$d/home/.local/bin"
  mkdir -p "$prefix/node_modules/.bin" "$bin"
  local t
  for t in ruff stylelint; do
    printf '#!/bin/sh\necho "%s (falso, de test)"\n' "$t" > "$prefix/node_modules/.bin/$t"
    chmod +x "$prefix/node_modules/.bin/$t"
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$prefix/node_modules/.bin/$t" > "$bin/$t"
    chmod +x "$bin/$t"
  done
}

# Copia el repo al sandbox, para poder romperlo a propósito.
copy_repo() {
  local d="$1"
  mkdir -p "$d/repo"
  # Sin `.git`: los tests no commitean nada, y un clon sin bit de ejecución
  # rompería el chmod de install.sh que hace el script.
  ( cd "$REPO" && tar -cf - --exclude=.git --exclude=PLAN.md . ) | ( cd "$d/repo" && tar -xf - )
  chmod +x "$d/repo/install.sh" "$d/repo/scripts/bpack"
}

# Corre nvim con la config del repo y captura stdout+stderr.
nvim_run() {
  nvim --headless "$@" 2>&1
}

# ── Aserciones ───────────────────────────────────────────────────────────────
ok()   { PASS=$((PASS+1)); printf '  %sok%s   %s\n' "$GREEN" "$OFF" "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  %sFALLA%s %s\n' "$RED" "$OFF" "$1"; }

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    ok "$msg"
  else
    bad "$msg"
    printf '       esperaba encontrar: %s\n' "$needle"
    printf '       y encontró:\n'
    printf '%s\n' "$haystack" | sed 's/^/         /' | head -12
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" != *"$needle"* ]]; then
    ok "$msg"
  else
    bad "$msg"
    printf '       no debia encontrar: %s\n' "$needle"
  fi
}

assert_eq() {
  if [[ "$1" == "$2" ]]; then
    ok "$3"
  else
    bad "$3 (esperaba '$2', obtuve '$1')"
  fi
}

assert_file() {
  if [[ -e "$1" ]]; then ok "$2"; else bad "$2 (no existe $1)"; fi
}

assert_no_file() {
  if [[ ! -e "$1" ]]; then ok "$2"; else bad "$2 (existe $1 y no deberia)"; fi
}

test_case() {
  CURRENT="$1"
  printf '%s%s%s\n' "$BOLD" "$1" "$OFF"
}

# ── Casos ────────────────────────────────────────────────────────────────────

t_arranque_limpio() {
  test_case "arranque limpio"
  local d; d="$(sandbox arranque)"; isolate "$d"; seed_tools "$d"
  nvim --headless -u "$REPO/init.lua" -c 'lua vim.defer_fn(function() vim.cmd("qa!") end, 80)' >/dev/null 2>&1
  local log="$d/state/nvim/bpack/bpack.log"
  if [[ ! -f "$log" ]]; then
    bad "se escribio el log de arranque"
    return
  fi
  ok "se escribio el log de arranque"
  assert_not_contains "$(cat "$log")" "ERROR en" "el arranque no registro errores"
}

t_doctor_verde() {
  test_case "doctor: todo en orden, y exit 0"
  local d; d="$(sandbox doctor)"; isolate "$d"; seed_tools "$d"
  local out; out="$(cd "$REPO" && ./scripts/bpack --doctor 2>/dev/null)"
  local rc=$?
  assert_contains "$out" "sin errores en este arranque" "el chequeo de arranque del doctor pasa"
  assert_contains "$out" "Todo en orden" "no reporta nada roto"
  assert_eq "$rc" "0" "sale con 0 cuando no hay errores"
}

t_doctor_detecta_intruso() {
  test_case "doctor: denuncia lo que no sea clon git en el pack dir"
  # Lo que bpack controla es la *detección*, no la reacción de vim.pack. Que un
  # directorio suelto en el pack dir rompa el sync es cosa de vim.pack (medido:
  # `pack.lua:251`, `fatal: not a git repository`, pero sólo cuando el spec
  # tiene plugins; con el spec vacío nunca camina el pack dir y parece inocuo).
  # Lo que sí es nuestro es no informar "Todo en orden" cuando hay algo ahí.
  local d; d="$(sandbox intruso)"; isolate "$d"; seed_tools "$d"
  mkdir -p "$d/data/nvim/site/pack/core/opt/__no_start_dir__"
  local out; out="$(cd "$REPO" && ./scripts/bpack --doctor 2>/dev/null)"
  assert_contains "$out" "__no_start_dir__" "nombra al intruso"
  assert_not_contains "$out" "Todo en orden" "no dice que este todo bien"

  # Un clon git de verdad no se reporta: es el caso normal del pack dir.
  d="$(sandbox intruso_ok)"; isolate "$d"; seed_tools "$d"
  mkdir -p "$d/data/nvim/site/pack/core/opt/un-clon"
  git -C "$d/data/nvim/site/pack/core/opt/un-clon" init -q 2>/dev/null
  out="$(cd "$REPO" && ./scripts/bpack --doctor 2>/dev/null)"
  assert_not_contains "$out" "un-clon" "un clon git no se reporta como intruso"
}

t_tools_estado() {
  test_case "toolchain: estados y shims"
  local d; d="$(sandbox tools)"; isolate "$d"; seed_tools "$d"
  local out; out="$(nvim_run -u "$REPO/init.lua" \
    -c 'lua for _,e in ipairs(require("bpack.toolchain").status()) do print("ESTADO:"..e.name..":"..e.state) end' \
    -c 'qa!')"
  assert_contains "$out" "ESTADO:ruff:instalada" "una herramienta sembrada figura como instalada"
  assert_contains "$out" "ESTADO:stylelint:instalada" "la segunda tambien"

  # Sin shim tiene que ser un estado aparte, no "instalada": si `install`
  # dijera "ya esta" con el shim ausente, la herramienta no estaria en el PATH y
  # el usuario se enteraria recien al invocarla.
  mv "$d/home/.local/bin/ruff" "$d/ruff.bak"
  out="$(nvim_run -u "$REPO/init.lua" \
    -c 'lua for _,e in ipairs(require("bpack.toolchain").status()) do if e.name=="ruff" then print("ESTADO:"..e.state) end end' \
    -c 'qa!')"
  assert_contains "$out" "ESTADO:sin shim" "sin shim es un estado propio, no 'instalada'"
}

t_tools_root_vacio() {
  test_case "toolchain: BPACK_TOOLS_ROOT vacio no apunta a /"
  # Regresión. En Lua la cadena vacía es truthy, así que
  # `vim.env.BPACK_TOOLS_ROOT or ~` con la variable vacía daba `""` y el prefijo
  # terminaba en `/.local/opt/bpack-tools`: la raíz del sistema. Basta un
  # `BPACK_TOOLS_ROOT=` en cualquier script para provocarlo.
  local d; d="$(sandbox rootvacio)"; isolate "$d"
  local out; out="$(BPACK_TOOLS_ROOT= nvim_run -u "$REPO/init.lua" \
    -c 'lua print("PREFIX:"..require("bpack.toolchain").prefix())' -c 'qa!')"
  assert_not_contains "$out" "PREFIX:/.local" "no cae en la raiz del sistema"
  assert_contains "$out" "PREFIX:$HOME" "cae en el home real"
}

t_dispatcher_bang() {
  test_case "dispatcher: el ! se separa del subcomando"
  # Regresión. El dispatcher nomaneja el `!`, así que `:Bpack selfupdate!` se
  # buscaba como subcomando llamado "selfupdate!" y no existía. El help lo
  # anunciaba igual: un falso positivo de documentacion.
  local d; d="$(sandbox bang)"; isolate "$d"; seed_tools "$d"
  local out; out="$(nvim_run -u "$REPO/init.lua" -c 'Bpack install! ruff' -c 'qa!')"
  assert_not_contains "$out" "no existe" "el subcomando con ! se resuelve"
  assert_not_contains "$out" "no conozco" "el argumento despues del ! se lee"
}

t_install_sin_bang_no_hace_nada() {
  test_case "install: sin ! pregunta, y en headless no instala"
  local d; d="$(sandbox sinbang)"; isolate "$d"
  seed_tools "$d"
  mv "$d/home/.local/bin/stylelint" "$d/stylelint.bak"
  local out; out="$(nvim_run -u "$REPO/init.lua" -c 'Bpack install' -c 'qa!')"
  assert_contains "$out" "¿Instalo" "pregunta antes de tocar el disco"
  assert_contains "$out" "cancelado" "en headless la respuesta por defecto es No"
  assert_no_file "$d/home/.local/bin/stylelint" "no se toco el disco sin permiso"
}

t_install_rechaza_no_repo() {
  test_case "install.sh: rechaza un directorio que no es repo bpack"
  local d; d="$(sandbox norepo)"; isolate "$d"
  mkdir -p "$d/fake"
  cp "$REPO/install.sh" "$d/fake/install.sh"
  chmod +x "$d/fake/install.sh"
  local out; out="$(echo n | bash "$d/fake/install.sh" 2>&1)"
  assert_contains "$out" "no parece un repo de bpack" "falla con un motivo claro"
}

t_install_cancela() {
  test_case "install.sh: cancelar no toca nada"
  local d; d="$(sandbox cancela)"; isolate "$d"; seed_tools "$d"
  copy_repo "$d"
  mkdir -p "$d/cfg/nvim"
  echo "CONFIG VIEJA" > "$d/cfg/nvim/init.lua"
  echo "dato personal" > "$d/cfg/nvim/mis-notas.txt"
  local before; before="$(find "$d/cfg" | sort)"
  local out; out="$(echo n | bash "$d/repo/install.sh" 2>&1)"
  assert_contains "$out" "cancelado" "dice que cancelo"
  assert_contains "$out" "No toqué nada" "dice explicitamente que no toco nada"
  assert_eq "$(find "$d/cfg" | sort)" "$before" "el arbol de config quedo igual"
  assert_eq "$(find "$d/cfg" -maxdepth 1 -name 'nvim.bak.*' | wc -l)" "0" "no creo backups"
}

t_install_monta() {
  test_case "install.sh: monta el stub y deja backup"
  local d; d="$(sandbox monta)"; isolate "$d"; seed_tools "$d"
  copy_repo "$d"
  mkdir -p "$d/cfg/nvim"
  echo "CONFIG VIEJA" > "$d/cfg/nvim/init.lua"
  echo "dato personal" > "$d/cfg/nvim/mis-notas.txt"
  local out; out="$(echo s | bash "$d/repo/install.sh" 2>&1)"
  assert_contains "$out" "arranque sin errores" "verifica el arranque antes de intercambiar"
  assert_file "$d/cfg/nvim/init.lua" "escribe el stub"
  assert_contains "$(cat "$d/cfg/nvim/init.lua")" "bpack: stub" "el stub lleva su marcador"
  assert_contains "$(cat "$d/cfg/nvim/init.lua")" "$d/repo/init.lua" "el stub apunta al repo"
  assert_eq "$(find "$d/cfg" -maxdepth 1 -name 'nvim.bak.*' | wc -l)" "1" "crea un backup"
  local bak; bak="$(find "$d/cfg" -maxdepth 1 -name 'nvim.bak.*' | head -1)"
  assert_contains "$(cat "$bak/mis-notas.txt" 2>/dev/null)" "dato personal" "el backup conserva los archivos personales"
  # Lo importante: el stub tiene que cargar la config de verdad, sin -u.
  local start; start="$(XDG_CONFIG_HOME="$d/cfg" nvim --headless -c 'qa!' 2>&1)"
  assert_not_contains "$start" "Error" "Neovim arranca con la config montada, sin -u"
}

t_install_idempotente() {
  test_case "install.sh: correrlo dos veces no mueve nada"
  local d; d="$(sandbox idem)"; isolate "$d"; seed_tools "$d"
  copy_repo "$d"
  mkdir -p "$d/cfg/nvim"
  echo "CONFIG VIEJA" > "$d/cfg/nvim/init.lua"
  echo s | bash "$d/repo/install.sh" >/dev/null 2>&1
  echo s | bash "$d/repo/install.sh" >"$d/second.log" 2>&1
  assert_contains "$(cat "$d/second.log")" "no muevo nada" "la segunda corrida no intercambia"
  assert_eq "$(find "$d/cfg" -maxdepth 1 -name 'nvim.bak.*' | wc -l)" "1" "sigue habiendo un solo backup"
}

t_install_verificacion_falla() {
  test_case "install.sh: si la verificacion falla, no intercambia"
  # Esta es la propiedad por la que existe el paso 5. El instalador viejo hacia
  # `mv` y despues `clone` al hueco; aca el intercambio es lo ultimo.
  local d; d="$(sandbox verifica)"; isolate "$d"; seed_tools "$d"
  copy_repo "$d"
  printf '\nerror("fallo deliberado del test")\n' >> "$d/repo/lua/bpack/theme.lua"
  mkdir -p "$d/cfg/nvim"
  echo "CONFIG VIEJA IMPORTANTE" > "$d/cfg/nvim/init.lua"
  echo "dato que no quiero perder" > "$d/cfg/nvim/mis-notas.txt"
  local out; out="$(echo s | bash "$d/repo/install.sh" 2>&1)"
  assert_contains "$out" "No toco tu config actual" "avisa que no toca la config"
  assert_contains "$(cat "$d/cfg/nvim/init.lua")" "CONFIG VIEJA IMPORTANTE" "la config vieja sigue ahi"
  assert_contains "$(cat "$d/cfg/nvim/mis-notas.txt")" "no quiero perder" "los archivos personales siguen ahi"
  assert_eq "$(find "$d/cfg" -maxdepth 1 -name 'nvim.bak.*' | wc -l)" "0" "no creo ningun backup"
}

# ── Tests de red (opt-in) ────────────────────────────────────────────────────
# No son tests: son la comprobación de que los releases y el npm siguen
# funcionando. Se dejan afuera de la suite porque dependen de que GitHub esté
# arriba, y un test que falla por red esconde los bugs de verdad.
t_network_tools() {
  test_case "toolchain: descarga real de un release de GitHub"
  local d; d="$(sandbox net)"; isolate "$d"
  # No se siembra nada: acá se verifica la descarga, el tar, y que el shim
  # quede ejecutable.
  local out; out="$(nvim_run -u "$REPO/init.lua" -c 'Bpack install! ruff' -c 'qa!')"
  if [[ "$out" != *"ruff instalada"* ]]; then
    bad "instalo ruff"
    printf '%s\n' "$out" | tail -5 | sed 's/^/       /'
    return
  fi
  ok "instalo ruff"
  local ver; ver="$("$d/home/.local/bin/ruff" --version 2>&1 | head -1)"
  assert_contains "$ver" "ruff" "el shim ejecuta el binario real"
}

# ── Corrida ──────────────────────────────────────────────────────────────────
if ! command -v nvim >/dev/null 2>&1; then
  printf '%sno encuentro nvim en el PATH%s\n' "$RED" "$OFF" >&2
  exit 1
fi

printf '%sbpack — tests de la config%s\n' "$BOLD" "$OFF"
printf '%sraíz de sandboxes: %s%s\n\n' "$DIM" "$SANDBOX_ROOT" "$OFF"

t_arranque_limpio
t_doctor_verde
t_doctor_detecta_intruso
t_tools_estado
t_tools_root_vacio
t_dispatcher_bang
t_install_sin_bang_no_hace_nada
t_install_rechaza_no_repo
t_install_cancela
t_install_monta
t_install_idempotente
t_install_verificacion_falla

if [[ "$NETWORK" == "1" ]]; then
  printf '\n%s(con red)%s\n' "$DIM" "$OFF"
  t_network_tools
else
  printf '\n  %sred apagada. Con BPACK_TEST_NETWORK=1 se agrega el test de descarga.%s\n' "$DIM" "$OFF"
fi

# Limpieza. `find -delete` en vez de `rm -rf`, para que un día un path mal
# formado no pueda borrar algo fuera del directorio de sandboxes.
if find "$SANDBOX_ROOT" -depth -delete 2>/dev/null; then
  :
else
  printf '\n  %sno pude limpiar los sandboxes. Quedan en %s%s\n' "$YELLOW" "$SANDBOX_ROOT" "$OFF"
fi

printf '\n%s%d ok, %d falla(s)%s\n' "$BOLD" "$PASS" "$FAIL" "$OFF"
[[ "$FAIL" -eq 0 ]]
