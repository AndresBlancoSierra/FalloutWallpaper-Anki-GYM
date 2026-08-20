# Tema rojo (modo ERROR en todo el escritorio)

`scripts/fallout-alert-mode.sh on|off` conmuta **todo el escritorio** a la
paleta roja de Fallout y lo revierte a la normal.

## Cómo funciona

- Hyprland, Waybar, SwayOSD, Hyprlock y terminales leen sus colores desde
  `~/.config/omarchy/current/theme/` (omarchy).
- El script convierte ese directorio en un **symlink** que apunta a:
  - `~/.config/fallout-wallpaper/theme-normal` → paleta normal (aether).
  - `~/.config/fallout-wallpaper/theme-red` → paleta roja derivada.
- En el primer `init()`:
  - Si `current/theme` ya no es nuestro symlink (p. ej. tras
    `omarchy theme set`), se captura el tema real actual como `theme-normal`.
  - Se re-deriva `theme-red` desde `theme-normal` aplicando el mapeo de
    colores (a continuación), sin tocar el symlink actual.
- **Mako** no lee el tema de omarchy: se le reescribe el color directo en
  `~/.config/mako/config`.

## Paleta de mapeo (aether → fallout)

| Aether (normal) | Fallout (rojo) |
| --------------- | -------------- |
| `020501` | `160000` (fondo) |
| `A9CC30` | `FF2020` (acento/borde) |
| `626660` | `7A3A3A` |
| `f0f8ee` | `FF9A9A` |
| `949855` | `C02828` |
| `9ad18d` | `FF4040` |
| `cdffa6` | `FF5A5A` |
| `304500` | `8A1A1A` |
| `c0a846` | `B02424` |
| `85ffb9` | `E04040` |
| `aaaf59` | `FF4D4D` |
| `a4ed93` | `FF8080` |
| `c7ff95` | `FF6B6B` |
| `22aa8a` | `B03030` |
| `dcbe35` | `D03A3A` |
| `b6d44f` | `FF5A5A` |
| `bfd964` | `FF7A7A` |
| `7f9924` | `A03030` |

`hyprlock.conf` usa `rgba(...)` decimal y se trata aparte (fondo `22,0,0`,
bordes `192,40,40`, acentos `255,32,32`).

> Si no usas omarchy, la idea es la misma: apunta el symlink del tema con el
> mapeo que quieras y recarga los componentes (`apply_restarts()` al final del
> script).

## Archivos implicados

- `~/.config/omarchy/current/theme` → symlink (`theme-normal`/`theme-red`).
- `~/.config/fallout-wallpaper/theme-{normal,red}` — snapshots generados.
- `~/.config/fallout-wallpaper/mako-config.normal` — backup del mako normal.
- `~/.config/mako/config` — rewrite de colores en rojo.

## Historial de estado

El script guarda el modo actual en `~/.config/fallout-wallpaper/mode.state`
(`RED` o `NORMAL`); lo usa el modo alerta roja (y el overlay de eww si está
activado, ver `docs/EWW.md`).