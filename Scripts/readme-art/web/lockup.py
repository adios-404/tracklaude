"""Writes the README's header: the Dial icon beside the word "tracklaude", light and dark.

The icon is Scripts/render-icon.swift's geometry redrawn as SVG, so its needle can sweep
from 0 to 70 % once when the page loads (and simply rest at 70 % for viewers who ask for
reduced motion). The word is Instrument Sans as outlines, from glyphs.swift, so the SVG
needs no font.

Usage: python3 lockup.py <wordmark.json> <out dir>
"""

import json
import math
import sys

# The icon's grid (render-icon.swift): a 1024 canvas, the dial centred at (512, 650).
CX, CY, R, W, LEVEL = 512.0, 650.0, 282.0, 76.0, 0.7
SWEEP = math.degrees(math.pi * LEVEL)  # how far the needle turns from 0 % to LEVEL
OVERSHOOT = 5.0  # degrees past LEVEL before it settles, as a real needle would
# Why the arc's true length rather than pathLength="100": Chrome drew the early frames of a
# normalised dash out of step with the needle. A dash the arc's real length keeps the
# coloured end under the needle's tip for the whole sweep.
ARC = math.pi * R * LEVEL
OVERSHOOT_LENGTH = ARC * OVERSHOOT / SWEEP


def num(v: float) -> str:
    return f"{v:.1f}".rstrip("0").rstrip(".")


def superellipse(center: float = 512.0, radius: float = 412.0, n: float = 5.0, steps: int = 360) -> str:
    """macOS's icon body: a superellipse on the 824-unit grid inside the 1024 canvas."""
    points = []
    for step in range(steps):
        t = step / steps * 2 * math.pi
        c, s = math.cos(t), math.sin(t)
        points.append((center + radius * math.copysign(abs(c) ** (2 / n), c),
                       center + radius * math.copysign(abs(s) ** (2 / n), s)))
    return "M" + " L".join(f"{num(x)} {num(y)}" for x, y in points) + " Z"


def on_dial(fraction: float, radius: float) -> tuple[float, float]:
    """A point on the dial's upper half: 0 at the left, 1 at the right (y down)."""
    return CX - radius * math.cos(math.pi * fraction), CY - radius * math.sin(math.pi * fraction)


def arc(to: float) -> str:
    (x0, y0), (x1, y1) = on_dial(0, R), on_dial(to, R)
    return f"M {num(x0)} {num(y0)} A {num(R)} {num(R)} 0 0 1 {num(x1)} {num(y1)}"


def ticks() -> str:
    lines = []
    for i in range(11):
        major = i % 5 == 0
        inner = R + W / 2 + 26
        (x1, y1), (x2, y2) = on_dial(i / 10, inner), on_dial(i / 10, inner + (34 if major else 20))
        lines.append(f'<line x1="{num(x1)}" y1="{num(y1)}" x2="{num(x2)}" y2="{num(y2)}" '
                     f'stroke-opacity="{0.55 if major else 0.3}"/>')
    return "".join(lines)


def needle() -> str:
    """Tapered from the hub to LEVEL, rounded at the tip, drawn at rest."""
    dx, dy = -math.cos(math.pi * LEVEL), -math.sin(math.pi * LEVEL)

    def at(along: float, side: float) -> tuple[float, float]:
        return CX + dx * along - dy * side, CY + dy * along + dx * side

    length, base, tip = 236.0, 19.0, 5.0
    body = " ".join(f"{num(x)},{num(y)}" for x, y in (at(-24, base), at(length, tip), at(length, -tip), at(-24, -base)))
    tx, ty = at(length, 0)
    return (f'<polygon points="{body}"/><circle cx="{num(tx)}" cy="{num(ty)}" r="{num(tip)}"/>'
            f'<circle cx="{num(CX)}" cy="{num(CY)}" r="48"/>')


STYLE = f"""
  .fill {{ stroke-dasharray: {num(ARC)} {num(ARC * 2)}; animation: fill 1.7s cubic-bezier(.3, .7, .2, 1) .35s both; }}
  .needle {{ transform-origin: {num(CX)}px {num(CY)}px; animation: sweep 1.7s cubic-bezier(.3, .7, .2, 1) .35s both; }}
  @keyframes fill {{ 0% {{ stroke-dashoffset: {num(ARC)}; }} 72% {{ stroke-dashoffset: {num(-OVERSHOOT_LENGTH)}; }} 100% {{ stroke-dashoffset: 0; }} }}
  @keyframes sweep {{ 0% {{ transform: rotate({num(-SWEEP)}deg); }} 72% {{ transform: rotate({num(OVERSHOOT)}deg); }} 100% {{ transform: rotate(0deg); }} }}
  @media (prefers-reduced-motion: reduce) {{ .fill, .needle {{ animation: none; }} }}
"""

ICON = f"""<defs>
  <linearGradient id="tile" gradientUnits="userSpaceOnUse" x1="512" y1="100" x2="512" y2="924">
    <stop offset="0" stop-color="#2D4878"/><stop offset="1" stop-color="#0F1B33"/>
  </linearGradient>
  <radialGradient id="sheen" gradientUnits="userSpaceOnUse" cx="360" cy="170" r="640">
    <stop offset="0" stop-color="#fff" stop-opacity=".13"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="gauge" gradientUnits="userSpaceOnUse" x1="{num(CX - R - W / 2)}" y1="0" x2="{num(CX + R * 0.6)}" y2="0">
    <stop offset="0" stop-color="#50D2A2"/><stop offset="1" stop-color="#F4B740"/>
  </linearGradient>
  <filter id="lift" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">
    <feDropShadow dx="0" dy="12" stdDeviation="12" flood-color="#000" flood-opacity=".35"/>
  </filter>
  <filter id="needle-shadow" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">
    <feDropShadow dx="0" dy="4" stdDeviation="5" flood-color="#000" flood-opacity=".35"/>
  </filter>
  <path id="tile-shape" d="{superellipse()}"/>
  <clipPath id="tile-clip"><use href="#tile-shape"/></clipPath>
</defs>
<use href="#tile-shape" fill="#1A2B4D" filter="url(#lift)"/>
<g clip-path="url(#tile-clip)"><rect width="1024" height="1024" fill="url(#tile)"/><rect width="1024" height="1024" fill="url(#sheen)"/></g>
<use href="#tile-shape" fill="none" stroke="#fff" stroke-opacity=".09" stroke-width="4"/>
<g fill="none" stroke-linecap="round">
  <path d="{arc(1)}" stroke="#fff" stroke-opacity=".14" stroke-width="{num(W)}"/>
  <path class="fill" d="{arc(LEVEL + OVERSHOOT / 180)}" stroke="url(#gauge)" stroke-width="{num(W)}"/>
  <g stroke="#fff" stroke-width="9">{ticks()}</g>
</g>
<g class="needle"><g filter="url(#needle-shadow)" fill="#fff">{needle()}</g><circle cx="{num(CX)}" cy="{num(CY)}" r="17" fill="#13213D"/></g>
"""


def lockup(wordmark: dict, fill: str, size: float = 64.0, icon: float = 120.0, gap: float = 18.0) -> str:
    """The icon, then the word at `size` px. The icon sits in a nested <svg> so the needle's
    transform-origin is measured in the icon's own 1024-unit space."""
    scale = size / 100.0  # glyphs.swift extracted the outlines at 100 px
    tile_middle = icon * 512 / 1024
    ascender = 0.765 * size  # height of t, k, l, d in Instrument Sans: centred on the tile
    baseline = tile_middle + ascender / 2
    x = icon * 924 / 1024 + gap
    width = x + wordmark["width"] * scale + 2
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {num(width)} {num(icon)}" width="{num(width)}" height="{num(icon)}" role="img" aria-label="tracklaude">
<style>{STYLE}</style>
<svg width="{num(icon)}" height="{num(icon)}" viewBox="0 0 1024 1024">
{ICON}</svg>
<path transform="translate({num(x)} {num(baseline)}) scale({scale})" fill="{fill}" d="{wordmark["d"]}"/>
</svg>
"""


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: lockup.py <wordmark.json> <out dir>")
    with open(sys.argv[1]) as source:
        word = json.load(source)
    for theme, colour in (("light", "#0F1B33"), ("dark", "#F0F4FA")):
        with open(f"{sys.argv[2]}/lockup-{theme}.svg", "w") as out:
            out.write(lockup(word, colour))
