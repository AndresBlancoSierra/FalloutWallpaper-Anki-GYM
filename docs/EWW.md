# Overlay "ERROR" (eww) y excepción de Anki

Cuando el modo ERROR está activo, una palabra **ERROR** flota **encima de
todas las ventanas** (capa `overlay` de Hyprland) pero con *click-through*:
los clics pasan a lo que haya debajo, así que no bloquea el trabajo.

## Componentes

| Archivo (`eww/`) | Rol |
| ---------------- | --- |
| `eww.yuck` | Define la ventana `errormode` (`:stacking "overlay"`, `:focusable "none"`, `:passthrough true`, `:namespace "fallout-error"`) + `defpoll` de animación |
| `eww.scss` | Transparencia de fondo del overlay |
| `errormode-render.py` | Renderiza la palabra con glow (ImageMagick) a partir del config |
| `errormode-frame.py` | Emite el CSS dinámico (opacidad + jitter) cada 0.12 s |
| `errormode-config.json` | Parámetros: posición, tamaño, spacing, escala, opacity, glow, anim, color |

## eww con passthrough (requisito)

El eww del repositorio de Arch **no** soporta `:passthrough`; hay que compilar
el fork con la PR #1437:

```bash
git clone --branch add-wayland-passthrough https://github.com/LemonKronos/eww.git
cd eww && cargo build --release --no-default-features --features=wayland
cp target/release/eww ~/.local/bin/eww
```

Ver `docs/INSTALL.md`. El daemon de eww se levanta **on-demand** desde
`scripts/fallout-alert-mode.sh` (`errormode_on`), sin depender del PATH.

## Flujo

1. `fallout-stats.html` detecta tareas pendientes → `POST /api/alert` →
   `serve.py` → `scripts/fallout-alert-mode.sh on`.
2. `errormode_on` arranca el daemon (si falta) y abre `errormode`.
3. Visibilidad real en la capa: `hyprctl layers` debe mostrar el namespace
   `fallout-error`.

> Tip: `eww list-windows` lista las ventanas **definidas**, no las abiertas.
> Para saber si el overlay está de verdad en pantalla, usa `hyprctl layers`.

## Posición y estética

- Posición (base) en `eww.yuck`: defvars `err_x` (margin-left) y `err_y`
  (margin-top). El frame.py solo añade el *jitter* de la animación.
- Config (`errormode-config.json`):
  ```json
  {
    "x": 240,       "y": 14,      // posición base (px, esquina sup-izq)
    "size": 256,    "letter": 21, // pointsize y letter-spacing del render
    "scale": 100,   "opacity": 100,
    "glow": true,   "anim": true, // glow de 3 capas / parpadeo+jitter
    "color": "#ff0000"
  }
  ```
- El render de la palabra es un **PNG estático** (hash de los parámetros
  visuales) → `errormode-word-<hash>.png` + copia estable
  `errormode-word.png`. La animación (parpadeo y micro-jitter) la aplica
  `errormode-frame.py` vía el `defpoll`, siguiendo los mismos keyframes que el
  CSS del wallpaper (`errpulse`/`errjitter`).
- Para re-renderizar tras cambiar size/letter/color: ejecuta
  `python3 ~/.config/eww/errormode-render.py`.

## Excepción de Anki

`scripts/fallout-anki-hider.sh` es un watcher que corre mientras el modo ERROR
está activo (lo levanta/mata `fallout-alert-mode.sh`):

- Cada segundo mira si hay una ventana con `class ~= anki` (`hyprctl clients`).
- **Anki abierto** → `eww close errormode` (Anki queda por encima: es la única
  ventana permitida sobre el texto de ERROR).
- **Anki cerrado** (y modo RED sigue) → `eww open errormode` (vuelve).

Lee el estado desde `~/.config/fallout-wallpaper/mode.state` (escrito por
`fallout-alert-mode.sh`).

## Auto-reparación

En `fallout-stats.html`, `checkAlert()` publica el estado de alerta cuando
**cambia**, y además hay un intervalo de 30 s que re-publica el estado actual
si sigue en alerta. Así, si el overlay o el hider mueren, `serve.py`
re-ejecuta `fallout-alert-mode.sh on` y se reabren solos.

## Depuración

```bash
pgrep -x eww                                # daemon vivo
hyprctl layers -j | grep -o fallout-error   # overlay visible/no
pgrep -af "fallout-anki-hider"              # watcher de Anki
cat ~/.config/fallout-wallpaper/mode.state  # RED / NORMAL
python3 ~/.config/eww/errormode-frame.py    # emite el CSS actual
```