#!/bin/bash
# scripts/focus-refresh.sh — servicio de sistema (root).
#
# Mientras el modo foco esté activo (flag focus-net.active):
#   - cada 30 s hace health-check de AdGuard: si está caído con el flag activo,
#     lo reinicia (Restart=always del override + este reintento) y re-aplica las
#     user_rules de la blocklist.
#
# Lo controla scripts/focus-net.sh on|off. Se instala como
# /etc/systemd/system/vaulttec-focus-refresh.service (setup/install.sh sustituye
# __REPO__/__HOME__). Si el flag desaparece, sale limpio (exit 0) y systemd no
# lo relanza (Restart=on-failure).

set -uo pipefail

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
DIR="$(dirname "$SELF")"
ROOT="$(dirname "$DIR")"

BASE="${HOME:-/home/andres}/.config/fallout-wallpaper"
ACTIVE_FLAG="$BASE/focus-net.active"
CREDS_FILE="$BASE/adguard.creds"
BLOCKLIST="$ROOT/adguard/blocklist.txt"
ADG_BASE="http://127.0.0.1:3015"

log()  { echo "[focus-refresh] $*"; }
warn() { echo "[focus-refresh] $*" >&2; }

root_run() { # root_run cmd...  (sudo -n salvo que ya seamos root)
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -n "$@"; fi
}

adguard_up() {
  [ -r "$CREDS_FILE" ] || return 1
  curl -s --connect-timeout 2 -m 5 -o /dev/null -w '%{http_code}' -u "$(cat "$CREDS_FILE")" \
    "$ADG_BASE/control/status" | grep -q '^200$'
}

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

apply_rules() { # set_rules + cache_clear desde la blocklist
  local rules
  rules="$(build_block_rules)"
  curl -s --connect-timeout 2 -m 5 -o /dev/null -u "$(cat "$CREDS_FILE")" \
    -H 'Content-Type: application/json' \
    -X POST "$ADG_BASE/control/filtering/set_rules" -d "{\"rules\":$rules}" \
    && curl -s --connect-timeout 2 -m 5 -o /dev/null -u "$(cat "$CREDS_FILE")" \
         -X POST "$ADG_BASE/control/cache_clear" \
    && log "user_rules re-aplicadas desde la blocklist."
}

rules_empty() { # 0 si user_rules vacías; 1 si presentes o ilegible
  local st
  st="$(curl -s --connect-timeout 2 -m 5 -u "$(cat "$CREDS_FILE")" \
        "$ADG_BASE/control/filtering/status" 2>/dev/null)" || return 1
  printf '%s' "$st" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
exit(0 if not (d.get("user_rules") or []) else 1)'
}

STATE_FILE="$BASE/mode.state"

while :; do
  state="$(cat "$STATE_FILE" 2>/dev/null)"

  # --- Coherencia estado/flag (self-heal del stack completo): el modo ERROR
  #     es la fuente de verdad. Si hay desajuste se re-sincroniza en ≤30 s,
  #     así un `boot` fallido o un toggle manual no dejan el sistema a medias.
  if [ "$state" = "RED" ]; then
    if [ ! -f "$ACTIVE_FLAG" ]; then
      warn "mode.state=RED sin flag; re-aplicando focus-net.sh on…"
      "$DIR/focus-net.sh" on >/dev/null 2>&1 || warn "focus-net.sh on falló"
    fi
  else
    if [ -f "$ACTIVE_FLAG" ]; then
      warn "flag presente pero mode.state=$state; focus-net.sh off…"
      "$DIR/focus-net.sh" off >/dev/null 2>&1 || warn "focus-net.sh off falló"
      exit 0
    fi
  fi

  if [ ! -f "$ACTIVE_FLAG" ]; then
    log "flag ausente, saliendo (off)."
    exit 0
  fi

  # --- Health-check de AdGuard: nunca debe quedar caído estando el modo activo.
  if ! adguard_up; then
    warn "AdGuard sin respuesta; reiniciándolo…"
    root_run systemctl restart adguardhome 2>/dev/null || warn "systemctl restart adguardhome falló"
    sleep 5
  fi

  # --- Integridad de reglas (self-heal): estando el modo activo las user_rules
  #     NUNCA deben quedar vacías (p. ej. un `on` previo con AdGuard inoperativo
  #     dejó flag+dropin sin reglas). Si vacías, se re-aplican en ≤30 s.
  if adguard_up && rules_empty; then
    warn "user_rules vacías estando el modo activo; re-aplicando blocklist…"
    apply_rules
  fi

  sleep 30
done