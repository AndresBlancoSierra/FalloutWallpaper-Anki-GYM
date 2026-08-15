#!/bin/bash
# fallout-alert-mode.sh on|off
#
# Cambia el tema de TODO el escritorio a la paleta roja "fallout" mientras el
# wallpaper está en estado de ERROR, y lo revierte a la paleta normal (aether)
# cuando se resuelve.
#
# Cómo funciona: los componentes (Hyprland, Waybar, SwayOSD, Hyprlock,
# terminales) leen sus colores desde ~/.config/omarchy/current/theme/. Aquí
# convertimos ese directorio en un symlink que apunta a theme-normal (aether)
# o theme-red (fallout). Mako no lee el tema: se le cambia el color en
# ~/.config/mako/config directamente.
#
# Init automático: si current/theme dejó de ser nuestro symlink (p.ej. después
# de `omarchy theme set`), se resincroniza theme-normal desde el tema real
# actual y se re-deriva theme-red aplicando la paleta roja.

set -euo pipefail

MODE="${1:-}"

BASE="$HOME/.config/fallout-wallpaper"
NORMAL="$BASE/theme-normal"
RED="$BASE/theme-red"
T="$HOME/.config/omarchy/current/theme"
MAKO="$HOME/.config/mako/config"
MAKO_NORMAL="$BASE/mako-config.normal"
STATE_FILE="$BASE/mode.state"

# Paleta roja fallout: mapeo aether (verde) -> rojo (hex 6 dígitos)
RED_PALETTE=(
  "020501 160000"
  "A9CC30 FF2020"
  "626660 7A3A3A"
  "f0f8ee FF9A9A"
  "949855 C02828"
  "9ad18d FF4040"
  "cdffa6 FF5A5A"
  "304500 8A1A1A"
  "c0a846 B02424"
  "85ffb9 E04040"
  "aaaf59 FF4D4D"
  "a4ed93 FF8080"
  "c7ff95 FF6B6B"
  "22aa8a B03030"
  "dcbe35 D03A3A"
  "b6d44f FF5A5A"
  "bfd964 FF7A7A"
  "7f9924 A03030"
)

redden() {
  local d="$1" m from to lfrom
  for m in "${RED_PALETTE[@]}"; do
    set -- $m
    from="$1"; to="$2"
    lfrom="$(echo "$from" | tr 'A-F' 'a-f')"
    # -I: ignorar binarios (imágenes de backgrounds, etc.)
    # `|| true`: si no hay coincidencias grep sale 1 y con pipefail abortaría
    grep -rl -I "$from" "$d" 2>/dev/null | while read -r f; do
      sed -i "s/$from/$to/g" "$f"
    done || true
    grep -rl -I "$lfrom" "$d" 2>/dev/null | while read -r f; do
      sed -i "s/$lfrom/$to/g" "$f"
    done || true
  done
  # hyprlock.conf usa colores en rgba decimal
  if [ -f "$d/hyprlock.conf" ]; then
    sed -i \
      -e 's/rgba(2, 5, 1, 1)/rgba(22, 0, 0, 1)/g' \
      -e 's/rgba(2, 5, 1, 0.66)/rgba(22, 0, 0, 0.66)/g' \
      -e 's/rgba(192, 168, 70, 1)/rgba(192, 40, 40, 1)/g' \
      -e 's/rgba(169, 204, 48, 1)/rgba(255, 32, 32, 1)/g' \
      -e 's/rgba(169, 204, 48, 0.7)/rgba(255, 32, 32, 0.7)/g' \
      -e 's/rgba(133, 255, 185, 1)/rgba(255, 32, 32, 1)/g' \
      "$d/hyprlock.conf"
  fi
}

init() {
  mkdir -p "$BASE"

  # Backup del mako normal (una sola vez), como fichero REAL. El backup
  # original quedó como symlink colgante (cp -a preserva el symlink si MAKO
  # apunta al tema) y hacía que `cp -a` abortara init() bajo set -e, dejando
  # theme-red sin reconstruir. Si MAKO ya está "enrojecido", se restaura desde
  # el mako.ini del tema normal.
  if [ ! -f "$MAKO_NORMAL" ]; then
    rm -f "$MAKO_NORMAL"
    if [ -f "$NORMAL/mako.ini" ]; then
      cp -a "$NORMAL/mako.ini" "$MAKO_NORMAL" 2>/dev/null || true
    elif [ -f "$MAKO" ]; then
      cp -a "$MAKO" "$MAKO_NORMAL" 2>/dev/null || true
    fi
  fi

  # Si current/theme ya no es nuestro symlink (primer run o `omarchy theme set`),
  # resincronizar el snapshot normal desde el tema real y pasar a symlink.
  # Si YA es nuestro symlink, se respeta el estado actual (NORMAL o RED).
  if [ ! -L "$T" ] || { [ "$(readlink "$T")" != "$NORMAL" ] && [ "$(readlink "$T")" != "$RED" ]; }; then
    rm -rf "$NORMAL"
    cp -a "$T" "$NORMAL" 2>/dev/null || mkdir -p "$NORMAL"
    rm -rf "$T"
    ln -s "$NORMAL" "$T"
    if [ -f "$MAKO_NORMAL" ]; then
      cp -a "$MAKO_NORMAL" "$MAKO" 2>/dev/null || true
    fi
  fi

  # Re-derivar RED desde NORMAL (frescura, sin tocar el symlink actual)
  rm -rf "$RED"
  cp -a "$NORMAL" "$RED"
  redden "$RED"

  # Validación: si NORMAL tenía hyprland.conf y RED no lo tiene, la derivación
  # falló a medias (p.ej. cp interrumpido) -> avisar para no repetir el error
  # de "source= globbing error" de hyprland.conf línea 13.
  if [ -f "$NORMAL/hyprland.conf" ] && [ ! -f "$RED/hyprland.conf" ]; then
    echo "[fallout] AVISO: theme-red derivado sin hyprland.conf (cp interrumpido?)" >&2
  fi
}

apply_restarts() {
  omarchy restart hyprctl >/dev/null 2>&1 || hyprctl reload >/dev/null 2>&1 || true
  omarchy restart waybar >/dev/null 2>&1 || true
  omarchy restart swayosd >/dev/null 2>&1 || true
  omarchy restart mako >/dev/null 2>&1 || true
  omarchy restart terminal >/dev/null 2>&1 || true
  pgrep -x foot >/dev/null && pkill -HUP -x foot 2>/dev/null || true
}

# eww con :passthrough (build custom); el daemon se levanta on-demand.
EWW_BIN="$HOME/.local/bin/eww"
ANKI_HIDER="$HOME/.local/bin/fallout-anki-hider.sh"
FOCUS_NET="$HOME/.local/bin/focus-net.sh"

errormode_on() {
  # Bloqueo de distracciones (AdGuard + dropin resolved, ver docs/FOCUS.md):
  # mientras el modo ERROR esté activo se bloquea solo la blocklist
  # (adguard/blocklist.txt); todo lo demás pasa. fail-closed: si AdGuard cae,
  # el DNS cae y systemd lo relanza en ~10 s.
  if [ -x "$FOCUS_NET" ]; then
    bash "$FOCUS_NET" on
  else
    echo "[fallout] aviso: falta $FOCUS_NET (setup/install.sh)"
  fi
  [ -x "$EWW_BIN" ] || return 0
  pgrep -x eww >/dev/null 2>&1 || { nohup "$EWW_BIN" daemon >/dev/null 2>&1 & sleep 0.5; }
  "$EWW_BIN" open errormode 2>/dev/null || true
  # Excepción de Anki: mientras Anki esté abierto, oculta el overlay para que
  # Anki quede encima del texto de error (única excepción permitida).
  if [ -x "$ANKI_HIDER" ] && ! pgrep -f "[f]allout-anki-hider.sh" >/dev/null 2>&1; then
    nohup bash "$ANKI_HIDER" >/dev/null 2>&1 &
  fi
}

errormode_off() {
  if [ -x "$FOCUS_NET" ]; then
    bash "$FOCUS_NET" off
  fi
  [ -x "$EWW_BIN" ] || return 0
  pgrep -x eww >/dev/null 2>&1 || return 0
  pgrep -f "[f]allout-anki-hider.sh" >/dev/null 2>&1 && pkill -f "[f]allout-anki-hider.sh" >/dev/null 2>&1 || true
  "$EWW_BIN" close errormode 2>/dev/null || true
}

case "$MODE" in
  on)
    init
    if [ "$(readlink "$T")" != "$RED" ]; then
      ln -sfn "$RED" "$T"
      if [ -f "$MAKO" ]; then
        sed -i \
          -e 's/^text-color=.*/text-color=#FF2020/' \
          -e 's/^border-color=.*/border-color=#FF2020/' \
          -e 's/^background-color=.*/background-color=#160000/' \
          "$MAKO"
      fi
      apply_restarts
    fi
    echo "RED" >"$STATE_FILE"
    errormode_on
    ;;
  off)
    init
    if [ "$(readlink "$T")" != "$NORMAL" ]; then
      ln -sfn "$NORMAL" "$T"
      if [ -f "$MAKO_NORMAL" ]; then
        cp -a "$MAKO_NORMAL" "$MAKO"
      fi
      apply_restarts
    fi
    echo "NORMAL" >"$STATE_FILE"
    errormode_off
    ;;
  *)
    echo "uso: fallout-alert-mode.sh on|off" >&2
    exit 1
    ;;
esac
