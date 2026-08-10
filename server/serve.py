#!/usr/bin/env python3
"""
VAULT-TEC SERVER — sirve fallout-stats.html desde $HOME (como el http.server
anterior) y expone un endpoint /api/gym que lee el vault de Obsidian de GYM
y devuelve el progreso en kg por ejercicio.

Cada .md dentro de GYM/{Push,Pull,Leg} es un ejercicio; cada fila de su tabla
es una sesión (columna 1 = peso en kg). Se calcula el aumento de kg entre la
primera y la última sesión con peso numérico.
"""

import json
import os
import subprocess
import tempfile
import threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("FALLOUT_PORT", "8123"))
GYM_ROOT = Path(os.environ.get(
    "GYM_ROOT", os.path.expanduser("~/Documents/obsidian/Me/GYM")))
POINTS_FILE = Path(os.environ.get(
    "POINTS_FILE", os.path.expanduser("~/Documents/obsidian/Me/points.md")))
GROUPS = ("Push", "Pull", "Leg")

# Stats que admiten clic manual (mismo orden/llaves que SPECIAL en el HTML)
MANUAL_STATS = ("PUSH", "PULL", "LEG", "VOLLEY", "MEDITATION", "DRAW")
# Fechas en ISO local (YYYY-MM-DD)
import datetime
_today = datetime.date.today
_today_str = lambda: _today().isoformat()


def _num(value):
    try:
        return float(str(value).strip().replace(",", "."))
    except (TypeError, ValueError):
        return None


def parse_gym():
    result = {}
    for group in GROUPS:
        folder = GYM_ROOT / group
        result[group] = []
        if not folder.is_dir():
            continue
        for md in sorted(folder.glob("*.md")):
            try:
                text = md.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            rows = []
            for line in text.splitlines():
                s = line.strip()
                if s.startswith("|"):
                    rows.append([c.strip() for c in s.strip("|").split("|")])
            sessions = []
            for r in rows[2:]:
                if not r:
                    continue
                w = _num(r[0])
                if w is not None:
                    sessions.append(w)
            if sessions:
                entry = {
                    "name": md.stem,
                    "initial": sessions[0],
                    "last": sessions[-1],
                    "delta": round(sessions[-1] - sessions[0], 2),
                    "sessions": len(sessions),
                }
            else:
                entry = {
                    "name": md.stem,
                    "initial": None,
                    "last": None,
                    "delta": None,
                    "sessions": 0,
                }
            result[group].append(entry)
    return result


def default_points():
    return {"counters": {s: 0 for s in MANUAL_STATS},
            "done": {}}


def parse_points():
    """Lee el bloque ```json ... ``` de points.md y devuelve counters/done."""
    data = default_points()
    try:
        text = POINTS_FILE.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return data
    block = None
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip().startswith("```json"):
            block = []
            for rest in lines[i + 1:]:
                if rest.strip().startswith("```"):
                    break
                block.append(rest)
            break
    if block is None:
        return data
    try:
        raw = json.loads("\n".join(block))
    except (TypeError, ValueError):
        return data
    counters = raw.get("counters") or {}
    done = raw.get("done") or {}
    data["counters"] = {s: counters.get(s, 0) for s in MANUAL_STATS}
    data["done"] = {str(k): str(v) for k, v in done.items()}
    return data


def write_points(data):
    """Escribe points.md de forma atómica (tmp + rename) preservando el bloque json."""
    counters = data.get("counters") or {}
    done = data.get("done") or {}
    payload = {"counters": {s: counters.get(s, 0) for s in MANUAL_STATS},
               "done": done}
    content = (
        "# Vault-Tec Points\n"
        "\n"
        "Base de datos de puntos (contadores diarios). No editar a mano.\n"
        "Se actualiza automáticamente al hacer clic en el wallpaper.\n"
        "\n"
        "```json\n"
        + json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n"
        "```\n"
    )
    POINTS_FILE.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(POINTS_FILE.parent),
                               prefix=".points.", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
        os.replace(tmp, str(POINTS_FILE))
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


class Handler(SimpleHTTPRequestHandler):
    def _send_json(self, obj, status=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _handle_alert(self):
        # El wallpaper avisa cuando cambia el estado de error y aquí cambiamos
        # el tema de TODO el escritorio a rojo (on) o lo revertimos (off).
        try:
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        except (ValueError, TypeError):
            payload = {}
        state = bool(payload.get("state"))
        mode = "on" if state else "off"
        script = os.path.expanduser("~/.local/bin/fallout-alert-mode.sh")
        try:
            subprocess.Popen([script, mode],
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
        except OSError:
            pass
        self._send_json({"ok": True, "mode": mode})

    def do_GET(self):
        if self.path.startswith("/api/gym"):
            try:
                self._send_json(parse_gym())
            except Exception:
                self._send_json({"error": "no se pudo leer el vault"})
            return
        if self.path.startswith("/api/points"):
            try:
                self._send_json(parse_points())
            except Exception:
                self._send_json({"error": "no se pudo leer points.md"}, status=500)
            return
        return super().do_GET()

    def do_POST(self):
        if self.path.startswith("/api/alert"):
            self._handle_alert()
            return
        if not self.path.startswith("/api/points"):
            self.send_response(404)
            self.end_headers()
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        except (ValueError, TypeError):
            self._send_json({"error": "json inválido"}, status=400)
            return
        stat = str(payload.get("stat") or "").upper()
        action = str(payload.get("action") or "").lower()
        if stat not in MANUAL_STATS or action not in ("inc", "dec"):
            self._send_json({"error": "stat/action inválidos"}, status=400)
            return
        try:
            data = parse_points()
            c = int(data["counters"].get(stat, 0))
            if action == "inc":
                c += 1
                data["done"][stat] = _today_str()
            else:
                c = max(0, c - 1)
                if data.get("done", {}).get(stat) == _today_str():
                    data["done"].pop(stat, None)
            data["counters"][stat] = c
            write_points(data)
            self._send_json(data)
        except Exception:
            self._send_json({"error": "no se pudo escribir points.md"}, status=500)

    def log_message(self, fmt, *args):
        pass

    def end_headers(self):
        # Sin caché: evita que Chromium/Brave sirva el HTML viejo por caching
        # heurístico (http.server no manda Cache-Control por defecto).
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        super().end_headers()


# Directorio desde el que se sirven los estáticos (fallout-stats.html + img/).
# En el despliegue original es $HOME; se puede apuntar a un checkout del repo
# (p. ej. FALLOUT_WEB_ROOT=$HOME/FalloutWallpaper-Anki-GYM).
WEB_ROOT = os.environ.get(
    "FALLOUT_WEB_ROOT", os.path.expanduser("~"))


def main():
    os.chdir(WEB_ROOT)
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"[vault-tec-serve] escuchando en http://127.0.0.1:{PORT} "
          f"(static root={WEB_ROOT})", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()