# Guía de instalación

> Entorno de referencia: Arch Linux + Hyprland + omarchy. Los conceptos valen
> para cualquier distro; adapta los nombres de paquetes.

## 1. Dependencias base

```bash
sudo pacman -S --needed python imagemagick brave hyprland waybar mako swayosd alacritty
```

Si no usas omarchy, instala además lo que quieras que participe del tema rojo
(waybar, mako, swayosd, foot/alacritty/kitty… ver `docs/THEME.md`).

## 2. Plugin hyprwinwrap (fondo tras las ventanas)

```bash
hyprpm add https://github.com/gen3vra/hyprwinwrap
hyprpm enable hyprwinwrap
exec-once = hyprpm reload   # en hyprland.conf (para que cargue al arrancar)
```

> **Tras cada actualización de Hyprland** (p. ej. `pacman -Syu` que toque
> `hyprland`): el binario del plugin queda compilado contra las cabeceras
> viejas y `hyprpm reload` falla en el arranque con:
> `headers are not up-to-date, please run hyprpm update`. Síntoma: el
> wallpaper de Fallout se ve como una ventana flotante normal en vez de
> quedarse de fondo. Solución:
>
> ```bash
> hyprpm update        # recompila hyprwinwrap contra el Hyprland actual
> ```
>
> después, relanza la ventana del wallpaper (matarla y `fallout.py` la crea de
> nuevo enrollada como fondo) o reinicia la sesión.

## 3. eww con `:passthrough` (opcional: solo para el overlay de ERROR)

El overlay de eww con el texto "ERROR" está **desactivado por defecto**
(`EWW_ENABLED=0` en `scripts/fallout-alert-mode.sh`); el modo alerta roja solo
cambia la paleta. Si quieres reactivarlo, compila este fork (el eww de los
repos de Arch no soporta `:passthrough`):

```bash
git clone --branch add-wayland-passthrough https://github.com/LemonKronos/eww.git ~/Proyects/eww-passthrough
cd ~/Proyects/eww-passthrough
cargo build --release --no-default-features --features=wayland
mkdir -p ~/.local/bin
cp target/release/eww ~/.local/bin/eww
```

Verifica: `eww --help | grep passthrough` debe mostrar la flag
`passthrough` (usa `--no-default-features --features=wayland`).
Asegúrate de que `~/.local/bin` tiene prioridad sobre el eww del sistema en tu
`PATH`.

## 4. Fuente VT323 (opcional: para el render del overlay eww)

```bash
mkdir -p ~/.local/share/fonts
curl -fsSL "https://github.com/google/fonts/raw/main/ofl/vt323/VT323-Regular.ttf" -o ~/.local/share/fonts/VT323-Regular.ttf
fc-cache -f
```

(`eww/errormode-render.py` resuelve la fuente con `fc-match VT323` y fallbacks;
puedes forzarla con la env `VT323_FONT`.)

## 5. Anki + AnkiConnect

- Instala Anki y el plugin **AnkiConnect** (Tools → Add-ons → código
  `2055492159`).
- La API queda en `http://127.0.0.1:8765` (la usa el wallpaper para contar
  tarjetas por mazo: `deckNames` + `findCards`).
- Los mazos que se sincronizan se definen en `fallout-stats.html` →
  `DECK_SYNC`:
  - **LANGUAGES**: mazo `Languages` (sub-mazos DE, MORSE…).
  - **HACKERMAN**: mazo `Hackerman` (sub-mazos AWS, CCNA, LFCS, SEC+, SQL, PY,
    OSCP…).
  - **EAR**: mazo `Ear Training`.
  - **GEORGIA**: mazo `Georgia`.

## 6. Instalar el repo

```bash
git clone https://github.com/AndresBlancoSierra/FalloutWallpaper-Anki-GYM ~/FalloutWallpaper-Anki-GYM
cd ~/FalloutWallpaper-Anki-GYM
bash setup/install.sh
```

El instalador es **idempotente** y hace:

1. Instala paquetes que falten (pacman) + plugin hyprwinwrap + eww custom.
2. Crea symlinks de `scripts/` → `~/.local/bin/` y de `eww/` → `~/.config/eww/`.
3. Crea `GYM/{Push,Pull,Leg}` y `points.md` (plantillas) si no existen.
4. Añade a `hyprland.conf` y `autostart.conf` los bloques marcados con
   `FalloutWallpaper-Anki-GYM` (idempotentes).

Para ver qué haría sin tocar nada: `bash setup/install.sh --dry-run`.

> **Rutas configurables**: `FALLOUT_WEB_ROOT` (raíz estática, por defecto el
> checkout), `GYM_ROOT`, `POINTS_FILE`, `HOME_BIN`.

## 7. Datos

- **Vault de GYM**: un `.md` por ejercicio en `GYM/{Push,Pull,Leg}`. Ver
  `templates/gym-exercise.example.md`. Ruta por defecto
  `~/Documents/obsidian/Me/GYM` (env `GYM_ROOT`).
- **points.md**: formato JSON en un bloque ``` ```json ``` ```. Ver
  `templates/points.example.md`. Ruta por defecto
  `~/Documents/obsidian/Me/points.md` (env `POINTS_FILE`).

## 8. Configurar (primer arranque)

- **Temas**: `scripts/fallout-alert-mode.sh` captura tu tema actual de omarchy
  como `theme-normal` y deriva `theme-red` automáticamente en el primer `on`.
  Solo necesitas tener el tema de omarchy activo.
- **Overlay de ERROR (eww)**: desactivado por defecto (`EWW_ENABLED=0`). Si lo
  reactivas (`EWW_ENABLED=1`), posición y estética en
  `~/.config/eww/eww.yuck` (defvars `err_x`, `err_y`) y
  `~/.config/eww/errormode-config.json`. Ver `docs/EWW.md`.
- **Comprobación**:
  ```bash
  curl -s http://127.0.0.1:8123/fallout-stats.html | head -c 80
  curl -s http://127.0.0.1:8123/api/gym
  curl -s http://127.0.0.1:8123/api/points
  ~/.local/bin/fallout-alert-mode.sh on   # prueba el modo ERROR
  ~/.local/bin/fallout-alert-mode.sh off  # y revierte
  ```

## 9. Arranque automático

Con el instalador, `autostart.conf` gana:

```ini
# >>> FalloutWallpaper-Anki-GYM <<<
exec-once = sleep 3 && FALLOUT_WEB_ROOT="…" python3 "…/server/serve.py"
exec-once = sleep 8 && python3 "…/launcher/fallout.py"
# >>> fin FalloutWallpaper-Anki-GYM <<<
```

Esto levanta el servidor (serve.py) y el orquestador (fallout.py → Brave) en
cada sesión. El modo alerta se auto-gestiona:

- `fallout-stats.html` evalúa las tareas pendientes al cargar y publica
  `/api/alert` (true/false) → `serve.py` llama a `fallout-alert-mode.sh`.
- `fallout-alert-mode.sh on` cambia el tema del escritorio a la paleta roja
  (y, si `EWW_ENABLED=1`, abre el overlay de eww).
- El estado de alerta se re-publica en el refresco manual (botón ⟳) y en el
  arranque.

## Troubleshooting rápido

| Síntoma | Causa probable |
| ------- | -------------- |
| No se ve el fondo | `hyprpm reload` / hyprwinwrap no cargado |
| `/api/*` responden 404 | serve.py no a la escucha o `FALLOUT_WEB_ROOT` mal |
| El tema rojo no aparece | `fallout-alert-mode.sh on` a mano; revisar `mode.state` |
| Anki no cuenta tarjetas | AnkiConnect apagado o el mazo no matchea `DECK_SYNC` |
| El overlay de eww no sale | Está desactivado (`EWW_ENABLED=0`); para activarlo ver sección 3 |