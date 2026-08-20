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
- **Lista de tareas**: las 10 actividades (GYM, VOLLEY, MEDITATION, DRAW,
  COOL SHOWER, READ, LANGUAGES, HACKERMAN, EAR, GEORGIA) se muestran en una
  sola columna compacta; todas quedan visibles sin hacer scroll.
- **Stats sincronizados con Anki** (LANGUAGES, HACKERMAN, EAR, GEORGIA) no
  tienen clic: muestran la cuenta regresiva **Unseen** (`X restantes de Y`)
  leída desde AnkiConnect, sin racha.

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
| LANGUAGES, HACKERMAN, EAR, GEORGIA | Automático: el contador **Unseen** del mazo bajó HOY al menos su **cuota** (nuevas aprendidas hoy) |

> **Meta Anki (cuota de nuevas/día)**: en el hint de cada mazo se muestra la
> cuenta regresiva y lo que falta de la meta, p. ej.
> `HACKERMAN: 4329 restantes de 4457 — faltan 25 nuevas para 25`, y
> `— meta 25 nuevas hoy ✓` al lograrla. Cuotas (`ANKI_QUOTAS` en el HTML):
> HACKERMAN 25, LANGUAGES 16, EAR 11, GEORGIA 5. El descenso del contador
> Unseen es el mismo dato que el add-on "More Overview Stats" (fiable también
> desde el móvil). HACKERMAN y LANGUAGES se desglosan por mazo hijo (casillas
> con logo debajo del Vault Boy), cada una con su propio contador restante.

## Modo ERROR (alerta roja)

Entra en ERROR mientras falte **cualquiera** de las tareas del día: **GYM** +
**VOLLEY** + **MEDITATION** + **DRAW** + **COOL SHOWER** + **READ** (marcado con
clic o al terminar un libro), o una categoría Anki sin su **cuota de nuevas**
de hoy (o con tarjetas sin ver). En ese estado **todo el escritorio cambia a la
paleta roja** (`fallout-alert-mode.sh` → theme-red) y el wallpaper se tiñe de
rojo (sin overlay de texto: la lista "ERROR / SIN COMPLETAR" se eliminó).

Al completar todo, vuelve la paleta normal.

### Reglas del modo ERROR

1. El cambio es solo **visual** (paleta roja + tinte en el wallpaper): no
   bloquea ventanas ni el uso del sistema.
2. El overlay de eww con el texto "ERROR" (`eww/errormode-render.py`) ya no se
   muestra por defecto: `EWW_ENABLED=0` en `scripts/fallout-alert-mode.sh`.
   Si quieres reactivarlo, pon `EWW_ENABLED=1` y revisa `docs/EWW.md`.

## Refresco manual y sync de Anki

En la barra de estado diario (`HOY: GYM — ✓GYM …`) hay un botón **⟳** que
actualiza todo a demanda y **sincroniza Anki** (AnkiConnect → AnkiWeb): rachas/
`done` desde `serve.py`, tarjetas de Anki, progreso de GYM, lista de libros, y
re-evalúa el modo ERROR. Al pulsarlo se muestra `SYNC ✓` en el hint.

El wallpaper **no sincroniza Anki automáticamente**: solo lo hace al pulsar
⟳. Anki sincroniza con AnkiWeb al **abrir/cerrar el perfil** (preferencia
por defecto de Anki) — así se evitan syncs forzados cada pocos minutos (lag y
tarjetas devueltas por conflictos). Los contadores se refrescan cada 60 s con
lecturas locales (sin sincronizar), y el descanso dominical de GYM se auto-suma.

## Almacenamiento

| Dato | Dónde |
| ---- | ----- |
| Rachas y "hecho hoy" | `points.md` (env `POINTS_FILE`) vía `serve.py` |
| Lista de libros (READ) | `Read/Read.md` (checkbox Obsidian: `[ ]`/`[x]`) |
| Progresión gym (kg) | vault GYM, `.md` por ejercicio (`GYM_ROOT`) |
| Contadores Anki (caché) | `localStorage` del perfil Brave (`vt_anki_cache`) |
| Nuevas aprendidas hoy (snapshot diario) | `localStorage` del perfil Brave (`vt_anki_snap`) |
| Estado del modo alerta | `~/.config/fallout-wallpaper/mode.state` (`RED`/`NORMAL`) |

## Comandos útiles

```bash
# Conmutar manualmente el modo ERROR (para probar)
~/.local/bin/fallout-alert-mode.sh on
~/.local/bin/fallout-alert-mode.sh off

# Ver qué hay en marcha
pgrep -af "serve.py|fallout.py"

# Logs
journalctl --user -b | grep -iE 'fallout|vault-tec'
```