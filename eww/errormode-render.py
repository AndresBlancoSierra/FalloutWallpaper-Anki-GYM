#!/usr/bin/env python3
"""Render the fallout ERROR word as a static PNG with glow, using ImageMagick.

Emulates the wallpaper's CSS for #err-word:
  color #ff0000; letter-spacing .08em; font-family VT323
  text-shadow: 0 0 4px #ff0000, 0 0 18px rgba(255,0,0,.8), 0 0 60px rgba(255,0,0,.5)

The opacity and the glitch flicker/jitter animation are applied live by eww
(errormode-frame.py) on top of this image, so they are NOT baked here.
"""

import glob
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

CONFIG_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG = os.path.join(CONFIG_DIR, "errormode-config.json")

# Fuente VT323: se resuelve automáticamente (fc-match) con respaldo a rutas
# habituales de instalación local del usuario; sobreescribible con VT323_FONT.
_DEFAULT_TTFS = (
    "/home/andres/.local/share/fonts/VT323-Regular.ttf",
    "/usr/share/fonts/TTF/VT323-Regular.ttf",
    "/usr/share/fonts/opentype/vt323/VT323-Regular.ttf",
)


def _vt323_path():
    env = os.environ.get("VT323_FONT")
    if env and os.path.exists(env):
        return env
    for p in _DEFAULT_TTFS:
        if os.path.exists(p):
            return p
    try:
        out = subprocess.run(["fc-match", "-f", "%{file}", "VT323"],
                             check=True, capture_output=True, text=True).stdout.strip()
        if out and os.path.exists(out):
            return out
    except Exception:
        pass
    return _DEFAULT_TTFS[0]


VT323 = _vt323_path()

# (blur_radius_px, alpha) per CSS text-shadow layer, back to front
GLOW_LAYERS = [(30, 0.5), (9, 0.8), (2, 1.0)]


def magick(args):
    subprocess.run(["magick", *args], check=True, capture_output=True)


def identify(path):
    out = subprocess.run(["magick", "identify", "-format", "%w %h", path],
                         check=True, capture_output=True, text=True).stdout
    w, h = out.split()
    return int(w), int(h)


def render(cfg):
    size = int(cfg["size"])
    letter = int(cfg["letter"])
    scale = float(cfg["scale"]) / 100.0
    color = cfg["color"]
    glow = bool(cfg["glow"])

    tmp = tempfile.mkdtemp(prefix="errormode-")
    try:
        mask = os.path.join(tmp, "mask.png")
        pad = int(size * 0.32) + 12
        magick(["-background", "none", "-fill", "white", "-font", VT323,
                "-pointsize", str(size), "-kerning", str(letter),
                "label:ERROR", mask])
        mask_pad = os.path.join(tmp, "mask_pad.png")
        magick([mask, "-bordercolor", "none", "-border", str(pad), mask_pad])

        base = os.path.join(tmp, "base.png")
        magick([mask_pad, "-fill", color, "-colorize", "100", base])

        if glow:
            glow_imgs = []
            for i, (r, a) in enumerate(GLOW_LAYERS):
                out = os.path.join(tmp, f"glow{i}.png")
                magick([mask_pad, "-blur", f"0x{r}", "-fill", color,
                        "-colorize", "100", "-channel", "A",
                        "-evaluate", "multiply", str(a), "+channel", out])
                glow_imgs.append(out)
            pre = os.path.join(tmp, "pre.png")
            magick([glow_imgs[0], glow_imgs[1], "-composite",
                    glow_imgs[2], "-composite", base, "-composite", pre])
        else:
            pre = base

        final = os.path.join(tmp, "final.png")
        magick([pre, "-resize", f"{scale * 100:.1f}%", final])
        w, h = identify(final)

        visual = {k: cfg.get(k) for k in ("size", "letter", "scale", "glow", "color")}
        ts = hashlib.md5(json.dumps(visual, sort_keys=True).encode()).hexdigest()[:10]
        out = os.path.join(CONFIG_DIR, f"errormode-word-{ts}.png")
        stable = os.path.join(CONFIG_DIR, "errormode-word.png")
        shutil.copy(final, out)
        shutil.copy(final, stable)

        for old in glob.glob(os.path.join(CONFIG_DIR, "errormode-word-*.*")):
            if old != out:
                os.remove(old)
        return out, w, h
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def load_config():
    with open(CONFIG) as fh:
        return json.load(fh)


if __name__ == "__main__":
    cfg = load_config()
    path, w, h = render(cfg)
    print(json.dumps({"path": path, "width": w, "height": h}))
