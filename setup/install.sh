#!/usr/bin/env bash
# setup/install.sh — instala FalloutWallpaper-Anki-GYM en un escritorio
# Hyprland (omarchy/Arch, probado en esa combi; adapta lo específico de tu
# distro si cambias). Es IDEMPOTENTE: se puede re-ejecutar sin romper nada.
#
# Qué hace:
#   1. Comprueba/instala dependencias (pacman + hyprpm + eww custom + VT323).
#   2. Despliega los scripts del repo a ~/.local/bin (symlinks).
#   3. Despliega la config de eww a ~/.config/eww (symlink).
#   4. Prepara datos: GYM_ROOT y points.md (a partir de plantillas si faltan).
#   5. Añade los fragmentos a hyprland.conf y autostart.conf (con marcadores).
#
# Rutas configurables vía variables de entorno:
#   FALLOUT_WEB_ROOT  raíz estática (por defecto: este checkout)
#   GYM_ROOT          vault de ejercicios (por defecto ~/Documents/obsidian/Me/GYM)
#   POINTS_FILE       archivo de puntos   (por defecto ~/Documents/obsidian/Me/points.md)
#   HOME_BIN           directorio bin del usuario (por defecto ~/.local/bin)
#
# Uso:
#   bash setup/install.sh
#   # PASO OPCIONAL suave: solo muestra el plan sin tocar nada
#   bash setup/install.sh --dry-run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
DRY=${1:-}

log()  { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }

FALLOUT_WEB_ROOT="${FALLOUT_WEB_ROOT:-$REPO}"
GYM_ROOT="${GYM_ROOT:-$HOME/Documents/obsidian/Me/GYM}"
POINTS_FILE="${POINTS_FILE:-$HOME/Documents/obsidian/Me/points.md}"
HOME_BIN="${HOME_BIN:-$HOME/.local/bin}"
EWW_DIR="$HOME/.config/eww"
EWW_CUSTOM_SRC="$HOME/Proyects/eww-passthrough"

echo "==> Repo: $REPO"
echo "==> Web root: $FALLOUT_WEB_ROOT (sirve fallout-stats.html + img/)"

# ---------------------------------------------------------------------------
if [ -n "$DRY" ]; then
  log "dry-run: no se modificará el sistema."
fi

# 0) Dependencias base (Arch: pacman + hyprpm)
paclist() { pacman -Qq 2>/dev/null | grep -qx "$1"; }
for p in python imagemagick brave hyprland waybar mako swayosd alacritty; do
  if ! paclist "$p"; then
    if [ -z "$DRY" ] && command -v pacman >/dev/null 2>&1; then
      log "instalando $p..."
      sudo pacman -S --needed --noconfirm "$p"
    else
      warn "falta el paquete '$p' (instálalo con pacman)."
    fi
  fi
done

# Plugin hyprwinwrap (necesario para el fondo)
if ! hyprpm list 2>/dev/null | grep -qi hyprwinwrap; then
  if [ -z "$DRY" ]; then
    log "instalando plugin hyprwinwrap via hyprpm..."
    hyprpm add https://github.com/gen3vra/hyprwinwrap || warn "revisa hyprpm add"
    hyprpm enable hyprwinwrap || warn "no se pudo habilitar hyprwinwrap"
  else
    warn "Falta el plugin hyprwinwrap (hyprpm add github.com/gen3vra/hyprwinwrap)."
  fi
fi

# 1) eww con :passthrough (build custom; ver docs/EWW.md)
if command -v eww >/dev/null 2>&1 && eww --help 2>&1 | grep -q passthrough 2>/dev/null; then
  log "eww custom encontrado en PATH."
elif [ -x "$HOME/.local/bin/eww" ]; then
  log "eww custom presente en ~/.local/bin/eww."
else
  if [ -z "$DRY" ]; then
    if ! command -v cargo >/dev/null 2>&1; then
      warn "se necesita rust/cargo para compilar eww. Instálalo con pacman."
    else
      log "clonando/compilando eww con passthrough (PR #1437)..."
      [ -d "$EWW_CUSTOM_SRC" ] || git clone \
        --branch add-wayland-passthrough --depth 1 \
        https://github.com/LemonKronos/eww.git "$EWW_CUSTOM_SRC"
      cd "$EWW_CUSTOM_SRC"
      cargo build --release --no-default-features --features=wayland
      cp target/release/eww "$HOME/.local/bin/eww"
    fi
  else
    warn "Falta el eww custom (versión con :passthrough). Se compilará en la instalación real."
  fi
fi

# Fuente VT323 (para el render del overlay)
if [ -z "$DRY" ]; then
  fc-match VT323 >/dev/null 2>&1 || {
    log "instalando VT323 (descarga de Google Fonts)..."
    mkdir -p "$HOME/.local/share/fonts"
    curl -fsSL -o "$HOME/.local/share/fonts/VT323-Regular.ttf" \
      https://github.com/google/fonts/raw/main/ofl/vt323/VT323-Regular.ttf \
      && fc-cache -f >/dev/null 2>&1 \
      || warn "no se pudo descargar VT323; instálala manualmente."
  }
fi

# 2) Scripts -> ~/.local/bin
mkdir -p "$HOME_BIN"
for s in fallout-alert-mode.sh fallout-anki-hider.sh fallout-wallpaper-toggle.sh \
         focus-net.sh focus-refresh.sh; do
  ln -sfn "$REPO/scripts/$s" "$HOME_BIN/$s"
  chmod +x "$REPO/scripts/$s" 2>/dev/null || true
  log "script ${s} -> $HOME_BIN/${s}"
done

# 2b) FOCUS — bloqueo de distracciones en modo ERROR (AdGuard, ver docs/FOCUS.md).
#     Idempotente: re-ejecutable sin romper nada.
FOCUS_BASE="$HOME/.config/fallout-wallpaper"
mkdir -p "$FOCUS_BASE"

if ! paclist adguardhome; then
  if [ -z "$DRY" ]; then
    log "instalando adguardhome (pacman)..."
    sudo pacman -S --needed --noconfirm adguardhome
  else
    warn "falta el paquete adguardhome (instálalo con pacman)."
  fi
fi
if [ -z "$DRY" ]; then
  sudo systemctl enable --now adguardhome >/dev/null 2>&1 || warn "adguardhome no arrancó; revisa: journalctl -u adguardhome"
fi

ADG_CREDS="$FOCUS_BASE/adguard.creds"
ADG_PORT=3015
# Configura AdGuard por API solo si aún no está configurado (estado != 200).
configure_adguard() {
  if [ -r "$ADG_CREDS" ] && curl -s -o /dev/null -w '%{http_code}' \
       -u "$(cat "$ADG_CREDS")" "http://127.0.0.1:$ADG_PORT/control/status" \
       | grep -q '^200$'; then
    log "AdGuard ya configurado (se reutilizan credenciales de $ADG_CREDS)."
    return 0
  fi
  log "configurando AdGuard por API (web 127.0.0.1:$ADG_PORT, DNS 127.0.0.1:53)..."
  ADG_PASS="$(python3 -c 'import secrets; print(secrets.token_hex(12))')"
  sleep 2   # esperar a que el servicio levante
  curl -s -o /dev/null -w '%{http_code}\n' \
    -H 'Content-Type: application/json' -X POST \
    "http://127.0.0.1:$ADG_PORT/control/install/configure" \
    -d "{\"web\":{\"ip\":\"127.0.0.1\",\"port\":$ADG_PORT,\"username\":\"admin\",\"password\":\"$ADG_PASS\"},\"dns\":{\"ip\":\"127.0.0.1\",\"port\":53}}"
  printf 'admin:%s\n' "$ADG_PASS" > "$ADG_CREDS"
  chmod 600 "$ADG_CREDS"
  # Upstream: NextDNS DoH (perfil 4c2f5c) + bootstrap. POST-only en /control/dns_config.
  curl -s -o /dev/null -u "admin:$ADG_PASS" -H 'Content-Type: application/json' \
    -X POST "http://127.0.0.1:$ADG_PORT/control/dns_config" \
    -d '{"upstream_dns":["https://dns.nextdns.io/4c2f5c"],"bootstrap_dns":["94.140.14.14","8.8.8.8"]}'
  log "AdGuard listo (creds: $ADG_CREDS)."
}
if [ -z "$DRY" ]; then
  configure_adguard || warn "la configuración de AdGuard falló; revisa adguardhome.service"
fi

# 2c) FOCUS — servicios de sistema (root): re-aplicar en boot + refrescar IPs +
#     AdGuard auto-reinicio (Restart=always). Se sustituyen __REPO__/__HOME__.
deploy_unit() { # deploy_unit <archivo-en-repo> <ruta-destino>
  local src="$REPO/systemd/$1" dst="$2" body
  body="$(sed -e "s|__REPO__|$REPO|g" -e "s|__HOME__|$HOME|g" "$src")"
  printf '%s\n' "$body" | sudo tee "$dst" >/dev/null
  log "unit ${1} -> ${dst}"
}
if [ -z "$DRY" ]; then
  deploy_unit vaulttec-focus-refresh.service /etc/systemd/system/vaulttec-focus-refresh.service
  deploy_unit vaulttec-focus-boot.service /etc/systemd/system/vaulttec-focus-boot.service
  sudo mkdir -p /etc/systemd/system/adguardhome.service.d
  deploy_unit adguardhome.service.d/override.conf /etc/systemd/system/adguardhome.service.d/override.conf
  sudo systemctl daemon-reload
  sudo systemctl enable vaulttec-focus-refresh.service vaulttec-focus-boot.service >/dev/null
  log "units habilitadas: vaulttec-focus-refresh, vaulttec-focus-boot"
  # Aplicar el estado actual (mode.state) sin esperar al próximo boot.
  sudo systemctl start vaulttec-focus-boot.service || warn "vaulttec-focus-boot falló en el arranque inmediato"
fi

# 3) Config eww -> ~/.config/eww
mkdir -p "$EWW_DIR"
for f in eww.yuck eww.scss errormode-render.py errormode-frame.py errormode-config.json; do
  ln -sfn "$REPO/eww/$f" "$EWW_DIR/$f"
  chmod +x "$REPO/eww/errormode-render.py" "$REPO/eww/errormode-frame.py" 2>/dev/null || true
  log "eww/${f} -> $EWW_DIR/${f}"
done

# 4) Datos: vault GYM + points.md (crea desde plantillas si no existen)
mkdir -p "$GYM_ROOT"/{Push,Pull,Leg}
if [ ! -e "$POINTS_FILE" ]; then
  mkdir -p "$(dirname "$POINTS_FILE")"
  cp "$REPO/templates/points.example.md" "$POINTS_FILE"
  log "points.md creado en ${POINTS_FILE}"
fi

# 5) Hyprland: fragmentos (idempotentes, con marcador)
append_block() { # file block_text
  local f="$1" txt="$2"
  if grep -q "FalloutWallpaper-Anki-GYM" "$f" 2>/dev/null; then
    log "ya presente en $f (se omite)"
  else
    { printf '\n'; cat; } <<<"$txt" >> "$f" || true
    log "bloque añadido a ${f}"
  fi
}

HYPR_DIR="$HOME/.config/hypr"
mkdir -p "$HYPR_DIR"
FWLAND_BLOCK="# >>> FalloutWallpaper-Anki-GYM <<<
windowrule = no_focus on, match:class (org.fallout.wallpaper)
windowrule = no_initial_focus on, match:class (org.fallout.wallpaper)
plugin {
    hyprwinwrap {
        class = org.fallout.wallpaper
        pos_x = 0
        pos_y = 0
        size_x = 100
        size_y = 100
    }
}
# >>> fin FalloutWallpaper-Anki-GYM <<<"
AUTO_BLOCK="# >>> FalloutWallpaper-Anki-GYM <<<
exec-once = sleep 3 && FALLOUT_WEB_ROOT=\"$FALLOUT_WEB_ROOT\" python3 \"$REPO/server/serve.py\"
exec-once = sleep 8 && python3 \"$REPO/launcher/fallout.py\"
# >>> fin FalloutWallpaper-Anki-GYM <<<"

[ -z "$DRY" ] && append_block "$HYPR_DIR/hyprland.conf" "$FWLAND_BLOCK"
[ -z "$DRY" ] && append_block "$HYPR_DIR/autostart.conf" "$AUTO_BLOCK"

# 6) Directorio de estado del modo alerta
mkdir -p "$HOME/.config/fallout-wallpaper"
[ -f "$HOME/.config/fallout-wallpaper/mode.state" ] || echo "NORMAL" > "$HOME/.config/fallout-wallpaper/mode.state"

log "¡Listo! Recarga la sesión de Hyprland (hyprctl reload) para activar los cambios."
log "Revisa el arranque con:  journalctl --user -b | grep -iE 'fallout|vault-tec'"
log "Más detalles en docs/INSTALL.md y docs/USAGE.md."