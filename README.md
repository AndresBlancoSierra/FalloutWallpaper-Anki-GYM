# FalloutWallpaper-Anki-GYM

Fondo de pantalla vivo estilo **Pip-Boy de Fallout** para Hyprland que fusiona tu
vida real con tus stats: rutina de **gimnasio** (PUSH/PULL/LEG con progresión en
kg leída de tu vault de Obsidian), **vóley**, **meditación**, **dibujo** y
repaso de tarjetas de **Anki** (Alemán + Hackerman).

Todo el escritorio se vuelve **rojo y muestra "ERROR" encima de todo** cuando
quedan tareas pendientes del día, y vuelve a la normalidad al completarlas.

---

## Qué hace

- **Pip-Boy animado**: selecciona automáticamente el stat del día (día de PULL →
  Vault Boy de PULL con la progresión en kg de dominadas, curl, remo…), con
  glitch/scanlines CRT, ruido y jitter.
- **Contadores diarios** con un clic: +1 / −1 en cada stat (persistidos en
  `points.md` vía `serve.py`).
- **Sync con AnkiConnect** cada 60 s: cuenta tarjetas aprendidas por mazo
  (Alemán y Hackerman) y las muestra en la interfaz.
- **Modo ERROR automático**: mientras falte completar la rutina del día
  (gimnasio + vóley + meditación + dibujo) o Hackerman/Alemán no superen las
  tarjetas del día anterior, todo el escritorio cambia a la paleta roja y un
  overlay de eww muestra la palabra **ERROR** flotando **encima de cualquier
  ventana** (pero *passthrough*: los clics siguen pasando).
- **Overlay con posicionamiento/animación tuneable** (glow, parpadeo, jitter,
  escala) emulado desde el CSS del wallpaper mediante ImageMagick + un
  `defpoll` de eww.
- **Excepción Anki**: si abres Anki, es la **única** ventana que se muestra
  por encima del texto de ERROR (el overlay se oculta mientras Anki está
  abierto y reaparece al cerrarlo).
- **Auto-reparación**: el wallpaper re-emite su estado de alerta cada 30 s, así
  que si el overlay cae por lo que sea, se reabre solo.
- **Automático al iniciar sesión**: sirve + lanza el fondo vía Hyprland
  (`autostart.conf`) y sobrevive a reinicios.

## Arquitectura

```
                    ┌────────────────────────────────────────────┐
                    │  Hyprland (hyprwinwrap de fondo)            │
                    │                                             │
  Brave app ───────►│  fallout-stats.html + img/ (Pip-Boy)        │
  (org.fallout.)    │      │ /api/alert (POST)                    │
   wallpaper        │      ▼                                     │
                    │  serve.py  ──► /api/gym  ──► GYM/{Push,..} │
                    │              └─► /api/points ─► points.md  │
                    └──────────┬─────────────────────────────────┘
                               │ subprocess: fallout-alert-mode.sh on|off
                               ▼
                    ┌────────────────────────────────────────────┐
                    │ tema rojo (theme-red symlink) + Waybar/Mako│
                    │ + overlay eww "ERROR" (passthrough)        │
                    │    └── fallout-anki-hider.sh (excepción)   │
                    └────────────────────────────────────────────┘
```

| Pieza | Archivo | Rol |
| ----- | ------- | --- |
| Página/fondo | `fallout-stats.html` | Todo el estado: stats, alerta, sync Anki |
| Servidor | `server/serve.py` | HTTP :8123, `/api/gym`, `/api/points`, `/api/alert` |
| Orquestador | `launcher/fallout.py` | Lanza/relanza Brave de fondo |
| Modo alerta | `scripts/fallout-alert-mode.sh` | Conmuta tema RED/NORMAL + overlay |
| Excepción Anki | `scripts/fallout-anki-hider.sh` | Oculta el overlay si Anki está abierto |
| Overlay eww | `eww/*` | Ventana "ERROR" encima de todo (passthrough) |
| Toggle clics | `scripts/fallout-wallpaper-toggle.sh` | SUPER+B → interactividad del fondo |

## Requisitos

- **Hyprland** + plugin **hyprwinwrap** (`hyprpm add gen3vra/hyprwinwrap`).
- **eww** compilado con soporte de `:passthrough` (PR #1437 → fork
  `LemonKronos/eww`, rama `add-wayland-passthrough`). Ver `docs/EWW.md`.
- **Brave/Chromium** (para el fondo), **python3**, **ImageMagick** (`magick`),
  fuente **VT323**.
- **Anki** con el plugin **AnkiConnect** (API en `127.0.0.1:8765`) para la
  parte de tarjetas.
- Opcional: **omarchy** para el conmutador de temas (waybar, mako, swayosd,
  terminales leen de `~/.config/omarchy/current/theme/`).

## Instalación rápida

```bash
git clone https://github.com/AndresBlancoSierra/FalloutWallpaper-Anki-GYM
cd FalloutWallpaper-Anki-GYM
bash setup/install.sh          # instala dependencias, despliega y configura
hyprctl reload
```

Instalación detallada → [`docs/INSTALL.md`](docs/INSTALL.md).
Uso diario → [`docs/USAGE.md`](docs/USAGE.md).
Modo ERROR / overlay → [`docs/EWW.md`](docs/EWW.md).
Tema rojo → [`docs/THEME.md`](docs/THEME.md).

## Estructura

```
FalloutWallpaper-Anki-GYM/
├── fallout-stats.html        # el fondo/Pip-Boy (toda la lógica)
├── img/                      # sprites (SPECIAL + perks)
├── server/serve.py           # API + estáticos
├── launcher/fallout.py       # orquestador Brave
├── scripts/                  # modo alerta, hider de Anki, toggle
├── eww/                      # overlay ERROR (yuck/scss/render/frame/config)
├── hypr/                     # fragmentos hyprland.conf y autostart.conf
├── templates/                # formatos de points.md y fichas de GYM
├── setup/install.sh          # instalador idempotente
└── docs/                     # documentación
```

## Datos de usuario (no en el repo)

- **points.md** y el **vault GYM/**: quedan en tu Obsidian
  (`~/Documents/obsidian/Me/…`). Las plantillas están en `templates/`.
- El **historial diario** de Hackerman/Alemán vive en el `localStorage` del
  perfil de Brave del wallpaper (`~/.config/fallout-wallpaper`).

## Licencia

MIT — ver [LICENSE](LICENSE). Las imágenes de perks/vault boys son de
*Fallout 4* (© Bethesda); se usan con fines personales.