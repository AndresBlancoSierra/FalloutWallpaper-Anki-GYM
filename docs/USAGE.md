# Uso diario

## La interfaz (Pip-Boy)

- **Selección automática**: al arrancar, el Vault Boy grande ya muestra el modo
  **GYM** con la rutina del día (lun/jue empuje, mar/vie tracción, mié/sáb
  piernas, con su progresión en kg); el domingo (descanso) muestra **BREAK**,
  sin imagen ni puntos. Puedes clicar cualquier stat de la lista.
- **Vault Boy**: clic izquierdo → `+1` (completa hoy: la racha sube), clic
  derecho → `−1` (deshace el día actual). El hint inferior indica el estado:
  - `CLIC IZQ → +1 · CLIC DER → −1` → se puede incrementar.
  - `YA CONTADO HOY ✓` / `MÁXIMO ALCANZADO` → hecho.
  - `HOY: BREAK — DESCANSO…` → domingo: el descanso suma solo, sin clic.
- **Rachas (barra 0–365)**: el valor de cada modo es su **racha** de días
  consecutivos. Si hoy aún no lo completas, la barra muestra 0; al completarlo
  sube +1 (y sigue si ayer también lo hiciste). Si un día se falla, la racha
  vuelve a 0.
- **READ**: el modo READ muestra tu lista de libros de Obsidian
  (`Read/Read.md`) con checkboxes — **TERMINADOS** y **EN PROGRESO**— y puedes
  marcar/desmarcar un libro clicando la checkbox directamente en el wallpaper.
- **Stats sincronizados con Anki** (Alemán, Hackerman) no tienen clic: se
  muestran `aprendidas / total (%)` desde AnkiConnect, sin racha.

Esto se sirve desde `http://127.0.0.1:8123/fallout-stats.html`. El fondo es
una ventana Brave gestionada por `launcher/fallout.py`; **SUPER+B** (`fallout-
wallpaper-toggle.sh`) activa la interactividad del fondo para poder hacer clic,
y al clicar otra ventana el fondo vuelve al modo pasivo.

## Qué se considera "hecho hoy"

| Stat | Cómo se marca |
| ---- | ------------- |
| GYM | Clic (+1) en días de gym (lun→sáb, según `GYM_DAYS` en el HTML); domingo BREAK suma solo |
| VOLLEY, MEDITATION, DRAW, COOL SHOWER | Clic (+1) cualquier día |
| READ | Clic (+1) cualquier día, **o** marca un libro como `[x]` terminado en el modo READ (auto-+1). Deshacer: clic derecho en READ |
| HACKERMAN, GERMAN | Automático: hoy debe haber **+10 tarjetas nuevas** sobre las de ayer |

> **Meta Anki (+10)**: en el hint de cada mazo (GERMAN/HACKERMAN) se muestra
> cuántas tarjetas nuevas faltan para cumplir la meta, p. ej.
> `HACKERMAN: 350 / 400 (87%) — faltan 7 para +10`, y `— meta +10 ✓` al lograrla.

## Modo ERROR

Entra en ERROR mientras falte **cualquiera** de las tareas del día: **GYM** +
**VOLLEY** + **MEDITATION** + **DRAW** + **COOL SHOWER** + **READ** (marcado con
clic o al terminar un libro), o **HACKERMAN/GERMAN** sin **+10 tarjetas**
sobre ayer. Todo el escritorio cambia a la paleta roja y aparece el overlay
**ERROR** (eww) encima de todas las ventanas:

```
ERROR          ← palabra fija, centrada
HOY: GYM — SIN COMPLETAR
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
3. **Reparación manual**: si el overlay falla (p. ej. se cayó eww), pulsa el
   botón **⟳** de la barra de estado diario para refrescarlo todo y reabrir el
   overlay. Ya no hay re-emisión automática cada 30 s.

## Refresco manual

En la barra de estado diario (`HOY: GYM — ✓GYM …`) hay un botón **⟳** que
actualiza todo a demanda: rachas/`done` desde `serve.py`, tarjetas de Anki,
progreso de GYM y lista de libros, y re-evalúa el modo ERROR. El wallpaper solo
sigue refrescando Anki/rachas/libros cada 60 s y el descanso dominical de GYM
se auto-suma; si quieres ver un cambio al instante, usa el botón.

## Almacenamiento

| Dato | Dónde |
| ---- | ----- |
| Rachas y "hecho hoy" | `points.md` (env `POINTS_FILE`) vía `serve.py` |
| Lista de libros (READ) | `Read/Read.md` (checkbox Obsidian: `[ ]`/`[x]`) |
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