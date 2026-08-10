# Uso diario

## La interfaz (Pip-Boy)

- **Selección automática**: al arrancar, el Vault Boy grande ya muestra el
  stat del día (día de PULL → PULL, con su progresión en kg) y el domingo
  (descanso) muestra MEDITACIÓN. Puedes clicar cualquier stat de la lista.
- **Vault Boy**: clic izquierdo → `+1` (marca hecho hoy), clic derecho → `−1`.
  El hint inferior indica el estado:
  - `CLIC IZQ → +1 · CLIC DER → −1` → se puede incrementar.
  - `YA CONTADO HOY ✓` / `MÁXIMO ALCANZADO` → hecho.
  - `HOY NO APLICA (…DÍA…)` → el stat de gym no toca hoy.
- **Stats sincronizados con Anki** (Alemán, Hackerman) no tienen clic: se
  muestran `aprendidas / total (%)` desde AnkiConnect.

Esto se sirve desde `http://127.0.0.1:8123/fallout-stats.html`. El fondo es
una ventana Brave gestionada por `launcher/fallout.py`; **SUPER+B** (`fallout-
wallpaper-toggle.sh`) activa la interactividad del fondo para poder hacer clic,
y al clicar otra ventana el fondo vuelve al modo pasivo.

## Qué se considera "hecho hoy"

| Stat | Cómo se marca |
| ---- | ------------- |
| PUSH / PULL / LEG | Clic (+1) en su día de la semana (ver `GYM_DAYS` en el HTML) |
| VOLLEY, MEDITATION, DRAW | Clic (+1) cualquier día |
| HACKERMAN, GERMAN | Automático: hoy debe haber **más** tarjetas aprendidas que ayer |

## Modo ERROR

Mientras falte **cualquiera** de las tareas del día, todo el escritorio cambia
a la paleta roja y aparece el overlay **ERROR** (eww) encima de todas las
ventanas:

```
ERROR          ← palabra fija, centrada
HOY: LEG — SIN COMPLETAR
HOY: VOLLEY — SIN COMPLETAR
…              ← lista dinámica de tareas pendientes
```

Al completar todo, la confetti… no: vuelve la paleta normal y el overlay se
cierra. El overlay es **tras click-through** (los clics pasan a lo que haya
debajo), así que no bloquea el trabajo.

### Reglas del modo ERROR

1. **Lista dinámica** debajo de la palabra: crece/encoge hacia abajo sin mover
   la palabra (que está fija y centrada).
2. **Excepción Anki**: al abrir Anki, el overlay se oculta → Anki queda
   visible, es la **única** ventana permitida encima del texto de ERROR.
   Al cerrar Anki (si el modo sigue activo) el overlay reaparece.
3. **Auto-reparación**: si el overlay falla, el wallpaper re-publica su estado
   cada 30 s y se reabre solo.

## Almacenamiento

| Dato | Dónde |
| ---- | ----- |
| Contadores y "hecho hoy" | `points.md` (env `POINTS_FILE`) vía `serve.py` |
| Progresión gym (kg) | vault GYM, `.md` por ejercicio (`GYM_ROOT`) |
| Tarjetas/días (Hackerman/Alemán) | `localStorage` del perfil Brave (`~/.config/fallout-wallpaper`) |
| Estado del modo alerta | `~/.config/fallout-wallpaper/mode.state` (`RED`/`NORMAL`) |

## Comandos útiles

```bash
# Conmutar manualmente el modo ERROR (para probar)
~/.local/bin/fallout-alert-mode.sh on
~/.local/bin/fallout-alert-mode.sh off

# Ver las capas (surface del overlay)
hyprctl layers

# Ver qué hay en marcha
pgrep -af "serve.py|fallout.py|fallout-anki-hider|eww"

# Logs
journalctl --user -b | grep -iE 'fallout|vault-tec|eww'
```