// What scene.html and social.html share: the menu bar and popover built from ReadmeArt's
// PNGs, and the wallpaper's dial (the app icon's gauge, enlarged).

const SVG_NS = 'http://www.w3.org/2000/svg';
const LEVEL = 0.7; // the icon's needle position, and so the dial's
const MINT = '#50D2A2', AMBER = '#F4B740';

/** The menu bar's markup: tracklaude's item (open), the system glyphs, then the clock. */
function menuBarHTML(clock) {
  return `<div class="menubar">
    <div class="pill" id="pill"><img data-src="item-live"></div>
    <img data-src="glyph-wifi"><img data-src="glyph-battery.75percent">
    <img data-src="glyph-magnifyingglass"><img data-src="glyph-switch.2">
    <div class="clock">${clock}</div>
  </div>`;
}

/** Points every img[data-src] at ReadmeArt's render for `theme`, at its size in points
 *  (ReadmeArt draws at 4x). Resolves once all have loaded, so layout can be measured. */
function loadArt(art, theme) {
  const images = [...document.querySelectorAll('img[data-src]')];
  return Promise.all(images.map(img => new Promise((done, fail) => {
    img.onload = () => { img.width = img.naturalWidth / 4; img.height = img.naturalHeight / 4; done(); };
    img.onerror = () => fail(new Error(`missing ${img.src}`));
    img.src = `${art}/${img.dataset.src}-${theme}.png`;
  })));
}

/** Draws the dial into the SVG group `into`: a glow, the track, the arc to LEVEL in
 *  mint → amber, and ticks at every 5 % — the icon's geometry at wallpaper size. */
function drawDial(into, { cx, cy, r, width, dark, glow, tickGap = 15, tickLength = [11, 20], tickWidth = [2.5, 3.5] }) {
  const svg = into.ownerSVGElement;
  const add = (parent, name, attrs) => {
    const e = document.createElementNS(SVG_NS, name);
    for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
    parent.appendChild(e);
    return e;
  };
  const at = (f, rad) => [cx - rad * Math.cos(Math.PI * f), cy - rad * Math.sin(Math.PI * f)];
  const arc = (to, rad) => {
    const [x0, y0] = at(0, rad), [x1, y1] = at(to, rad);
    return `M ${x0} ${y0} A ${rad} ${rad} 0 0 1 ${x1} ${y1}`;
  };

  // The icon's gradient runs left to right across the dial, not along the arc.
  const defs = add(svg, 'defs', {});
  const gradient = add(defs, 'linearGradient', { id: 'gauge', gradientUnits: 'userSpaceOnUse',
    x1: cx - r - width, y1: 0, x2: cx + r * 0.6, y2: 0 });
  add(gradient, 'stop', { offset: 0, 'stop-color': MINT });
  add(gradient, 'stop', { offset: 1, 'stop-color': AMBER });
  const blur = add(defs, 'filter', { id: 'glow', filterUnits: 'userSpaceOnUse',
    x: -2000, y: -2000, width: 6000, height: 6000 });
  add(blur, 'feGaussianBlur', { stdDeviation: width * 0.85 });

  const stroke = { fill: 'none', 'stroke-linecap': 'round' };
  add(into, 'path', { ...stroke, d: arc(LEVEL, r), stroke: 'url(#gauge)', 'stroke-width': width * 2.6,
    filter: 'url(#glow)', opacity: glow });
  add(into, 'path', { ...stroke, d: arc(1, r), 'stroke-width': width,
    stroke: dark ? 'rgba(255,255,255,0.07)' : 'rgba(26,43,77,0.065)' });
  add(into, 'path', { ...stroke, d: arc(LEVEL, r), stroke: 'url(#gauge)', 'stroke-width': width,
    opacity: dark ? 0.95 : 0.92 });
  for (let i = 0; i <= 20; i++) {
    const major = i % 5 === 0;
    const inner = r + width / 2 + tickGap, outer = inner + tickLength[major ? 1 : 0];
    const [x1, y1] = at(i / 20, inner), [x2, y2] = at(i / 20, outer);
    const alpha = major ? (dark ? 0.30 : 0.24) : (dark ? 0.15 : 0.12);
    add(into, 'line', { x1, y1, x2, y2, 'stroke-linecap': 'round', 'stroke-width': tickWidth[major ? 1 : 0],
      stroke: dark ? `rgba(255,255,255,${alpha})` : `rgba(26,43,77,${alpha})` });
  }
}
