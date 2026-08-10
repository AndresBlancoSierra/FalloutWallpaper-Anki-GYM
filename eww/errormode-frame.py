#!/usr/bin/env python3
"""Emits eww CSS for the errormode word at the current animation time.

Called by eww's defpoll every ~0.12s. Outputs the opacity (base config
opacity combined with the wallpaper's errpulse flicker) and the errjitter
micro-translation, both following the same keyframes as fallout-stats.html.

Output format: "opacity:0.6; margin-left:-2px; margin-top:1px;"
"""

import json
import os
import sys
import time

CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "errormode-config.json")

# errpulse keyframes: (t, opacity, scale)
PULSE = [(0.0, 1.00, 1.000), (0.25, 0.35, 1.030), (0.50, 1.00, 0.990),
         (0.75, 0.45, 1.020), (1.00, 1.00, 1.000)]
# errjitter keyframes: (t, dx, dy)
JITTER = [(0.00, 0, 0), (0.33, -2, 1), (0.66, 2, -1), (1.00, -1, 2)]


def lerp(a, b, t):
    return a + (b - a) * t


def sample(keyframes, t, default):
    for i in range(len(keyframes) - 1):
        t0, *v0 = keyframes[i]
        t1, *v1 = keyframes[i + 1]
        if t0 <= t <= t1:
            f = (t - t0) / (t1 - t0)
            return [lerp(v0[k], v1[k], f) for k in range(len(v0))]
    return default


def main():
    try:
        with open(CONFIG) as fh:
            cfg = json.load(fh)
    except Exception:
        cfg = {}
    opacity = float(cfg.get("opacity", 100)) / 100.0
    anim = bool(cfg.get("anim", True))

    if not anim:
        sys.stdout.write(f"opacity:{opacity:.3f};")
        return

    t = (time.time() % 0.8) / 0.8
    o, _s = sample(PULSE, t, [1.0, 1.0])
    dx, dy = sample(JITTER, t, [0, 0])
    sys.stdout.write(
        f"opacity:{opacity * o:.3f};"
        f"margin-left:{dx}px;margin-top:{dy}px;")


if __name__ == "__main__":
    main()
