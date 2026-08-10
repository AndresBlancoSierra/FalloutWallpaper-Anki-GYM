#!/bin/bash
# fallout-anki-hider.sh — excepción de Anki al overlay de ERROR.
#
# Mientras el modo ERROR está activo, el overlay de eww (la palabra "ERROR"
# encima de todo) se oculta cuando Anki está abierto, de forma que Anki sea la
# única ventana que quede encima del texto de error. Cuando Anki se cierra, el
# overlay vuelve a aparecer (si el modo ERROR sigue activo).
#
# Lo inicia/apaga fallout-alert-mode.sh (errormode_on / errormode_off).

EWW_BIN="$HOME/.local/bin/eww"
BASE="$HOME/.config/fallout-wallpaper"
STATE_FILE="$BASE/mode.state"          # "RED" o "NORMAL" (lo escribe fallout-alert-mode.sh)
NS="fallout-error"

anki_open() {
  hyprctl clients -j 2>/dev/null | grep -qiE '"class"\s*:\s*"[^"]*anki[^"]*"'
}

overlay_open() {
  hyprctl layers -j 2>/dev/null | grep -q "$NS"
}

sync() {
  [ "$(cat "$STATE_FILE" 2>/dev/null)" = "RED" ] || return 0
  if anki_open; then
    if overlay_open; then
      "$EWW_BIN" close errormode >/dev/null 2>&1 || true
    fi
  elif ! overlay_open; then
    "$EWW_BIN" open errormode >/dev/null 2>&1 || true
  fi
}

while true; do
  sync
  sleep 1
done