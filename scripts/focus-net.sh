#!/bin/bash
# scripts/focus-net.sh on|off|boot
#
# Activa/desactiva el "modo foco" de internet mientras el wallpaper está en
# ERROR (mode.state=RED): BLOQUEA solo la blocklist de distracciones
# (adguard/blocklist.txt) vía AdGuard. TODO lo demás pasa sin filtrar
# (Anki, deepseek/opencode, ChatGPT, GitHub, lo que sea) -> no interfiere.
#
# Capa única de bloqueo (ver docs/FOCUS.md):
#   1. DNS   : dropin /etc/systemd/resolved.conf.d/zzz-vaulttec-focus.conf
#              apunta systemd-resolved a AdGuard local (127.0.0.1:53).
#              Gana por orden lexicográfico sobre nextdns.conf (usb-key-monitor
#              no puede revertirlo) y el DNS= vacío resetea la lista de NextDNS.
#              FallbackDNS= vacío -> fail-closed: si AdGuard cae no hay DNS y
#              todo queda bloqueado (lo relanza systemd en ~10 s).
#   2. Reglas : user_rules de AdGuard = ||dominio^ de la blocklist (+ @@ para
#              excepciones). Sin catch-all: lo no listado PASA.
#
# `on` es IDEMPOTENTE (corto-circuito): el JS del wallpaper re-emite el estado
# cada ~30 s, y las llamadas repetidas deben ser instantáneas, nunca apilar
# procesos ni reiniciar systemd-resolved en bucle.
#
# Se instala como servicio de sistema:
#   - vaulttec-focus-boot.service    : arranque (lee mode.state, modo `boot`)
#   - vaulttec-focus-refresh.service : health-check de AdGuard cada 30 s
#
# Dependencias: adguardhome instalado y configurado (setup/install.sh),
# credenciales en ~/.config/fallout-wallpaper/adguard.creds.
# Corre como root (servicio) o con sudo -n (CLI).

set -uo pipefail

MODE="${1:-}"

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DIR="$(dirname "$SELF")"
ROOT="$(dirname "$DIR")"

ADG_HOST="127.0.0.1"
ADG_PORT="${ADG_PORT:-3015}"
ADG_BASE="http://$ADG_HOST:$ADG_PORT"
BASE="$HOME/.config/fallout-wallpaper"
CREDS_FILE="$BASE/adguard.creds"
BLOCKLIST="$ROOT/adguard/blocklist.txt"
REFRESH_UNIT="vaulttec-focus-refresh.service"
ACTIVE_FLAG="$BASE/focus-net.active"
STATE_FILE="$BASE/mode.state"
RESOLVED_DROPIN="/etc/systemd/resolved.conf.d/zzz-vaulttec-focus.conf"

log()  { printf '\033[1;31m[focus]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[focus]\033[0m %s\n' "$*"; }

root_run() { # root_run cmd...  (sudo -n salvo que ya seamos root)
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@"; fi
}

adguard_api() { # adguard_api METHOD PATH JSON
  local method="$1" path="$2" body="${3:-}"
  local args=(-s --connect-timeout 2 -m 5 -u "$(cat "$CREDS_FILE")" -H 'Content-Type: application/json' -X "$method" "$ADG_BASE$path")
  if [ -n "$body" ]; then
    curl "${args[@]}" -d "$body"
  else
    curl "${args[@]}"
  fi
}

adguard_up() {
  [ -r "$CREDS_FILE" ] || return 1
  curl -s --connect-timeout 2 -m 5 -o /dev/null -w '%{http_code}' -u "$(cat "$CREDS_FILE")" \
    "$ADG_BASE/control/status" | grep -q '^200$'
}

# build_block_rules -> JSON de user_rules:
#   línea "dominio"     -> ||dominio^          (bloquear)
#   línea "@dominio"    -> @@||dominio^        (excepción dentro de un bloqueo)
# Sin "/.*/": lo no listado PASA.
build_block_rules() {
  python3 - "$BLOCKLIST" <<'PY'
import json, sys
rules = []
for line in open(sys.argv[1]):
    d = line.strip()
    if not d or d.startswith("#"):
        continue
    if d.startswith("@"):
        d = d.lstrip("@")
        rules.append("@@||%s^" % d)
    else:
        rules.append("||%s^" % d)
print(json.dumps(rules))
PY
}

dns_dropin_on() {
  # DNS= vacío resetea la lista de nextdns.conf (las listas en systemd se
  # mezclan entre dropins; sin el reset nuestro 127.0.0.1 se añade, no sustituye)
  { printf '[Resolve]\nDNS=\nDNS=127.0.0.1\nDNSOverTLS=no\nFallbackDNS=\n'; } | root_run tee "$RESOLVED_DROPIN" >/dev/null
  root_run systemctl restart systemd-resolved 2>/dev/null || warn "no se pudo reiniciar systemd-resolved"
}

dns_dropin_off() {
  root_run rm -f "$RESOLVED_DROPIN"
  root_run systemctl restart systemd-resolved 2>/dev/null || true
}

already_active() { # flag + dropin en su sitio
  [ -f "$ACTIVE_FLAG" ] && [ -f "$RESOLVED_DROPIN" ]
}

case "$MODE" in
  on)
    # Las user_rules se (re)aplican SIEMPRE con AdGuard up (set_rules es
    # idempotente y barato; ya no hay re-emit de 30 s). Si AdGuard no responde
    # o rechaza, salimos SIN crear flag/dropin para no dejar un estado atascado
    # sin reglas (lo cura además vaulttec-focus-refresh.service en ≤30 s).
    if adguard_up; then
      RULES="$(build_block_rules)"
      N_RULES="$(echo "$RULES" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))')"
      CODE="$(curl -s --connect-timeout 2 -m 5 -o /dev/null -w '%{http_code}' \
        -u "$(cat "$CREDS_FILE")" -H 'Content-Type: application/json' \
        -X POST "$ADG_BASE/control/filtering/set_rules" -d "{\"rules\":$RULES}")"
      if [ "$CODE" = "200" ]; then
        adguard_api POST "/control/cache_clear" >/dev/null
        log "DNS: user_rules de AdGuard aplicadas/re-aplicadas ($N_RULES reglas)."
      else
        warn "AdGuard rechazó set_rules (HTTP $CODE); sin tocar flag/dropin."
        exit 1
      fi
    else
      warn "AdGuard no está operativo; revisa: servicio adguardhome y $CREDS_FILE (sin tocar flag/dropin)."
      exit 1
    fi

    # Idempotente YA solo para la infraestructura (flag/dropin/systemd-resolved):
    # no reiniciar systemd-resolved en bucle si el bloqueo ya estaba aplicado.
    if already_active; then
      log "ya activo; omitiendo infraestructura (flag + dropin presentes)."
      root_run systemctl is-active "$REFRESH_UNIT" >/dev/null 2>&1 \
        || root_run systemctl start "$REFRESH_UNIT" 2>/dev/null || true
    else
      touch "$ACTIVE_FLAG"
      dns_dropin_on
      root_run systemctl start "$REFRESH_UNIT" 2>/dev/null \
        || warn "no se pudo iniciar $REFRESH_UNIT (¿instalado? setup/install.sh)"
      log "$REFRESH_UNIT activo."
    fi

    root_run resolvectl flush-caches 2>/dev/null || true
    log "listo. Verificación: resolvectl query youtube.com (debe fallar) / music.youtube.com (debe resolver)"
    ;;
  off)
    log "restaurando internet…"
    rm -f "$ACTIVE_FLAG"
    root_run systemctl stop "$REFRESH_UNIT" 2>/dev/null || true
    pgrep -f "[f]ocus-refresh.sh" >/dev/null 2>&1 && pkill -f "[f]ocus-refresh.sh" >/dev/null 2>&1 || true
    if adguard_up; then
      adguard_api POST "/control/filtering/set_rules" '{"rules":[]}' >/dev/null
      adguard_api POST "/control/cache_clear" >/dev/null
      log "DNS: user_rules vacías (normal)."
    else
      warn "AdGuard no contesta; el DNS quedará como estaba."
    fi
    dns_dropin_off
    root_run resolvectl flush-caches 2>/dev/null || true
    log "hecho."
    ;;
  boot)
    # Re-aplica el estado tras un arranque (vaulttec-focus-boot.service):
    # mode.state=RED -> on; cualquier otra cosa -> off.
    # En el boot AdGuard puede tardar en estar listo (arranca con la red);
    # se espera activamente hasta FOCUS_BOOT_TIMEOUT (poll cada 2 s) antes de
    # dar por caído el servicio. Si aun así no responde, se sale con error y
    # systemd (Restart=on-failure) reintenta en ~10 s.
    if [ "$(cat "$STATE_FILE" 2>/dev/null)" = "RED" ]; then
      waited=0
      while [ "$waited" -lt "${FOCUS_BOOT_TIMEOUT:-30}" ] && ! adguard_up; do
        sleep 2
        waited=$((waited + 2))
      done
      if ! adguard_up; then
        warn "AdGuard no operativo tras ${waited}s; mode.state=RED sin aplicar (lo reintenta el servicio)."
        exit 1
      fi
      exec "$0" on
    else
      exec "$0" off
    fi
    ;;
  *)
    echo "uso: focus-net.sh on|off|boot" >&2
    exit 1
    ;;
esac