# Ejercicio de ejemplo

Ficha de ejercicio en el vault de GYM: `GYM/Pull/<Ejercicio>.md`
(un .md por ejercicio; el nombre del archivo es el nombre mostrado).

| Peso (kg) | 1 set | 2 set | 3 set |
| --------- | ----- | ----- | ----- |
| -10       | 5     | 12    | 12    |
| 0         | 6     | 6     | 6     |
| 5         | 4     | 4     | 4     |

- La **primera columna** es el peso en kg de cada fila/sesión.
- serve.py toma esa columna para calcular `initial`, `last`, `delta` y el
  número de `sessions` (filas con peso numérico).
- Un valor no numérico se ignora (la sesión no cuenta).
- La tabla debe empezar con una cabecera: la columna de peso en la posición 0.
- Estructura esperada del vault:
  ```
  GYM/
  ├── Push/  # un .md por ejercicio
  ├── Pull/
  └── Leg/
  ```
- Rutas por defecto: `~/Documents/obsidian/Me/GYM` (override con `GYM_ROOT`).