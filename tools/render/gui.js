// Approximate Roblox GUI layout in the DOM, for preview images.
// Supports: UDim2 position/size/anchor, rotation, background/border,
// ZIndex (sibling), ClipsDescendants, text (TextScaled fitting, wrap,
// alignment, stroke), UICorner, UIStroke, UIPadding, UIListLayout,
// UIGridLayout, UIAspectRatioConstraint, UISizeConstraint,
// UITextSizeConstraint, UIScale, UIGradient (simplified), CanvasGroup,
// ScrollingFrame (clipped), AutomaticSize for text and list containers.
// It is an emulation for layout review, not Roblox's renderer.

const FAMILIES = {
  Oswald: "Oswald",
  RobotoCondensed: "Roboto Condensed",
  RobotoMono: "Roboto Mono",
  SpecialElite: "Special Elite",
  PermanentMarker: "Permanent Marker",
  SourceSansPro: "Arial",
  GothamSSm: "Arial",
  BuilderSans: "Arial",
  Arimo: "Arial",
};
const WEIGHTS = { Thin: 100, ExtraLight: 200, Light: 300, Regular: 400, Medium: 500, SemiBold: 600, Bold: 700, ExtraBold: 800, Heavy: 900 };
const MODS = new Set(["UICorner", "UIStroke", "UIPadding", "UIListLayout", "UIGridLayout", "UIAspectRatioConstraint", "UITextSizeConstraint", "UISizeConstraint", "UIScale", "UIGradient"]);
const TEXT = new Set(["TextLabel", "TextButton", "TextBox"]);
const IMAGE = new Set(["ImageLabel", "ImageButton"]);

function family(font) {
  const m = /families\/([A-Za-z]+)\.json/.exec(font?.family || "");
  return FAMILIES[m ? m[1] : "SourceSansPro"] || "Arial";
}
function rgba(c, t = 0) {
  return `rgba(${c[0]},${c[1]},${c[2]},${Math.max(0, Math.min(1, 1 - t))})`;
}
// Lua encodes empty tables as {} so normalise every child list to an array.
function kidsOf(node) {
  return Array.isArray(node.kids) ? node.kids : [];
}
function modsOf(node) {
  const m = {};
  for (const k of kidsOf(node)) if (MODS.has(k.c)) m[k.c] = k;
  return m;
}
function guiKids(node) {
  return kidsOf(node).filter((k) => !MODS.has(k.c) && k.visible !== false);
}

let measurer;
function measure(node, fontSize, maxWidth) {
  if (!measurer) {
    measurer = document.createElement("div");
    measurer.style.cssText = "position:absolute;visibility:hidden;left:-20000px;top:0;";
    document.body.appendChild(measurer);
  }
  measurer.style.fontFamily = `'${family(node.font)}'`;
  measurer.style.fontWeight = WEIGHTS[node.font?.weight] || 400;
  measurer.style.fontStyle = node.font?.style === "Italic" ? "italic" : "normal";
  measurer.style.fontSize = fontSize + "px";
  measurer.style.lineHeight = String(1.12 * (node.lineHeight || 1));
  measurer.style.whiteSpace = node.wrapped ? "pre-wrap" : "pre";
  measurer.style.width = node.wrapped && maxWidth ? maxWidth + "px" : "auto";
  setText(measurer, node);
  const r = measurer.getBoundingClientRect();
  return { w: r.width, h: r.height };
}

function setText(el, node) {
  const text = node.text || "";
  if (node.rich) {
    const safe = text
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/&lt;br\s*\/?&gt;/g, "<br>")
      .replace(/&lt;(\/?)(b|i|u)&gt;/g, "<$1$2>")
      .replace(/&lt;font color="(#[0-9a-fA-F]{6})"&gt;/g, '<span style="color:$1">')
      .replace(/&lt;font color="rgb\((\d+),\s*(\d+),\s*(\d+)\)"&gt;/g, '<span style="color:rgb($1,$2,$3)">')
      .replace(/&lt;\/font&gt;/g, "</span>");
    el.innerHTML = safe;
  } else {
    el.textContent = text;
  }
}

function scaledSize(node, w, h, constraint) {
  const max = Math.min(100, constraint?.max ?? 100);
  const min = constraint?.min ?? 1;
  let lo = 1, hi = Math.floor(max), best = 1;
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    const s = measure(node, mid, w);
    if (s.w <= w + 0.5 && s.h <= h + 0.5) { best = mid; lo = mid + 1; } else hi = mid - 1;
  }
  return Math.max(best, min);
}

function childSize(k, cw, ch) {
  let w = k.size[0] * cw + k.size[1];
  let h = k.size[2] * ch + k.size[3];
  const m = modsOf(k);
  if (m.UISizeConstraint) {
    const c = m.UISizeConstraint;
    w = Math.min(Math.max(w, c.min[0]), c.max[0] > 0 ? c.max[0] : Infinity);
    h = Math.min(Math.max(h, c.min[1]), c.max[1] > 0 ? c.max[1] : Infinity);
  }
  if (m.UIAspectRatioConstraint) {
    const a = m.UIAspectRatioConstraint.ratio;
    if (m.UIAspectRatioConstraint.kind === "ScaleWithParentSize") {
      if (m.UIAspectRatioConstraint.axis === "Height") w = h * a; else h = w / a;
    } else if (w / Math.max(h, 1e-6) > a) w = h * a; else h = w / a;
  }
  if (TEXT.has(k.c) && k.auto && k.auto !== "None" && !k.scaled) {
    const s = measure(k, k.textSize, k.auto === "Y" ? w : undefined);
    const pad = modsOf(k).UIPadding;
    const padY = pad ? pad.t[1] + pad.b[1] : 0;
    const padX = pad ? pad.l[1] + pad.r[1] : 0;
    if (k.auto === "Y" || k.auto === "XY") h = Math.max(h, s.h + padY);
    if (k.auto === "X" || k.auto === "XY") w = Math.max(w, s.w + padX);
  }
  return { w, h };
}

function sortOrder(kids, sort) {
  const idx = kids.map((_, i) => i);
  if (sort === "LayoutOrder") idx.sort((a, b) => (kids[a].order - kids[b].order) || (a - b));
  else idx.sort((a, b) => kids[a].n.localeCompare(kids[b].n));
  return idx;
}

function listLayout(kids, sizes, L, cw, ch) {
  const vertical = L.dir === "Vertical";
  const pad = vertical ? L.pad[0] * ch + L.pad[1] : L.pad[0] * cw + L.pad[1];
  const order = sortOrder(kids, L.sort);
  const total = order.reduce((s, i) => s + (vertical ? sizes[i].h : sizes[i].w), 0) + pad * Math.max(0, order.length - 1);
  let cursor = vertical
    ? (L.v === "Center" ? (ch - total) / 2 : L.v === "Bottom" ? ch - total : 0)
    : (L.h === "Center" ? (cw - total) / 2 : L.h === "Right" ? cw - total : 0);
  const rects = [];
  for (const i of order) {
    const s = sizes[i];
    if (vertical) {
      const x = L.h === "Center" ? (cw - s.w) / 2 : L.h === "Right" ? cw - s.w : 0;
      rects[i] = { x, y: cursor, w: s.w, h: s.h };
      cursor += s.h + pad;
    } else {
      const y = L.v === "Center" ? (ch - s.h) / 2 : L.v === "Bottom" ? ch - s.h : 0;
      rects[i] = { x: cursor, y, w: s.w, h: s.h };
      cursor += s.w + pad;
    }
  }
  return { rects, extent: total };
}

function gridLayout(kids, G, cw, ch) {
  const cellW = G.cell[0] * cw + G.cell[1], cellH = G.cell[2] * ch + G.cell[3];
  const padX = G.pad[0] * cw + G.pad[1], padY = G.pad[2] * ch + G.pad[3];
  const order = sortOrder(kids, G.sort);
  const horizontal = G.dir !== "Vertical";
  const perLine = horizontal
    ? Math.max(1, Math.floor((cw + padX) / (cellW + padX)))
    : Math.max(1, Math.floor((ch + padY) / (cellH + padY)));
  const lines = Math.ceil(order.length / perLine);
  const usedW = horizontal ? Math.min(order.length, perLine) * (cellW + padX) - padX : lines * (cellW + padX) - padX;
  const usedH = horizontal ? lines * (cellH + padY) - padY : Math.min(order.length, perLine) * (cellH + padY) - padY;
  const offX = G.h === "Center" ? (cw - usedW) / 2 : G.h === "Right" ? cw - usedW : 0;
  const offY = G.v === "Center" ? (ch - usedH) / 2 : G.v === "Bottom" ? ch - usedH : 0;
  const rects = [];
  order.forEach((i, n) => {
    const a = n % perLine, b = Math.floor(n / perLine);
    const col = horizontal ? a : b, row = horizontal ? b : a;
    rects[i] = { x: offX + col * (cellW + padX), y: offY + row * (cellH + padY), w: cellW, h: cellH };
  });
  return { rects, extent: horizontal ? usedH : usedW };
}

function layoutChildren(node, el, w, h) {
  const m = modsOf(node);
  const p = m.UIPadding;
  const pl = p ? p.l[0] * w + p.l[1] : 0, pr = p ? p.r[0] * w + p.r[1] : 0;
  const pt = p ? p.t[0] * h + p.t[1] : 0, pb = p ? p.b[0] * h + p.b[1] : 0;
  const cw = Math.max(0, w - pl - pr), ch = Math.max(0, h - pt - pb);
  const kids = guiKids(node);
  const sizes = kids.map((k) => childSize(k, cw, ch));
  let rects, extent = 0;
  if (m.UIListLayout) ({ rects, extent } = listLayout(kids, sizes, m.UIListLayout, cw, ch));
  else if (m.UIGridLayout) ({ rects, extent } = gridLayout(kids, m.UIGridLayout, cw, ch));
  else rects = kids.map((k, i) => ({
    x: k.pos[0] * cw + k.pos[1] - k.anchor[0] * sizes[i].w,
    y: k.pos[2] * ch + k.pos[3] - k.anchor[1] * sizes[i].h,
    w: sizes[i].w, h: sizes[i].h,
  }));
  kids.forEach((k, i) => renderNode(k, el, rects[i].x + pl, rects[i].y + pt, rects[i].w, rects[i].h, i));
  return { extent, pad: pt + pb };
}

function renderText(node, el, w, h, m) {
  const inner = document.createElement("div");
  const pad = m.UIPadding;
  const pl = pad ? pad.l[0] * w + pad.l[1] : 0, pr = pad ? pad.r[0] * w + pad.r[1] : 0;
  const pt = pad ? pad.t[0] * h + pad.t[1] : 0, pb = pad ? pad.b[0] * h + pad.b[1] : 0;
  const iw = Math.max(0, w - pl - pr), ih = Math.max(0, h - pt - pb);
  inner.style.cssText = `position:absolute;left:${pl}px;top:${pt}px;width:${iw}px;height:${ih}px;display:flex;flex-direction:column;`;
  inner.style.justifyContent = node.yAlign === "Top" ? "flex-start" : node.yAlign === "Bottom" ? "flex-end" : "center";
  const span = document.createElement("div");
  const size = node.scaled ? scaledSize(node, iw, ih, m.UITextSizeConstraint) : node.textSize;
  span.style.fontFamily = `'${family(node.font)}'`;
  span.style.fontWeight = WEIGHTS[node.font?.weight] || 400;
  span.style.fontStyle = node.font?.style === "Italic" ? "italic" : "normal";
  span.style.fontSize = size + "px";
  span.style.lineHeight = String(1.12 * (node.lineHeight || 1));
  span.style.color = rgba(node.textColor, node.textT);
  span.style.whiteSpace = node.wrapped ? "pre-wrap" : "pre";
  span.style.textAlign = node.xAlign === "Left" ? "left" : node.xAlign === "Right" ? "right" : "center";
  const shadows = [];
  if (node.strokeT < 1) {
    const c = rgba(node.strokeColor, node.strokeT);
    shadows.push(`1px 0 ${c}`, `-1px 0 ${c}`, `0 1px ${c}`, `0 -1px ${c}`);
  }
  if (m.UIStroke && m.UIStroke.mode !== "Border") {
    const c = rgba(m.UIStroke.color, m.UIStroke.transparency), t = m.UIStroke.thickness;
    shadows.push(`${t}px 0 ${c}`, `-${t}px 0 ${c}`, `0 ${t}px ${c}`, `0 -${t}px ${c}`);
  }
  if (shadows.length) span.style.textShadow = shadows.join(",");
  setText(span, node);
  inner.appendChild(span);
  el.appendChild(inner);
}

function renderNode(node, parentEl, x, y, w, h, index) {
  const el = document.createElement("div");
  el.className = "rbx-" + node.c;
  el.dataset.name = node.n;
  el.style.position = "absolute";
  el.style.left = x + "px";
  el.style.top = y + "px";
  el.style.width = Math.max(0, w) + "px";
  el.style.height = Math.max(0, h) + "px";
  el.style.boxSizing = "border-box";
  el.style.zIndex = String(node.z * 100 + index);
  const m = modsOf(node);
  const transforms = [];
  if (node.rot) transforms.push(`rotate(${node.rot}deg)`);
  if (m.UIScale) {
    transforms.push(`scale(${m.UIScale.scale})`);
    // Roblox scales around the AnchorPoint (the position stays put)
    const a = node.anchor || [0, 0];
    el.style.transformOrigin = `${a[0] * 100}% ${a[1] * 100}%`;
  }
  if (transforms.length) el.style.transform = transforms.join(" ");
  if (node.bgT < 1 && !(node.c === "SurfaceGui" || node.c === "ScreenGui")) el.style.background = rgba(node.bg, node.bgT);
  const shadows = [];
  if (node.border > 0 && node.bgT < 1) shadows.push(`0 0 0 ${node.border}px ${rgba(node.borderColor, node.bgT)}`);
  if (m.UICorner) el.style.borderRadius = (m.UICorner.r[0] * Math.min(w, h) + m.UICorner.r[1]) + "px";
  if (m.UIStroke && (m.UIStroke.mode === "Border" || !TEXT.has(node.c))) {
    shadows.length = 0;
    shadows.push(`0 0 0 ${m.UIStroke.thickness}px ${rgba(m.UIStroke.color, m.UIStroke.transparency)}`);
  }
  if (shadows.length) el.style.boxShadow = shadows.join(",");
  if (node.clip || node.c === "ScrollingFrame") el.style.overflow = "hidden";
  if (node.c === "CanvasGroup") el.style.opacity = String(1 - (node.groupT || 0));
  if (m.UIGradient && m.UIGradient.enabled) {
    const g = m.UIGradient;
    const angle = 90 + (g.rotation || 0);
    if (Array.isArray(g.transparency) && g.transparency.length > 1) {
      const stops = g.transparency.map(([t, v]) => `rgba(0,0,0,${1 - v}) ${t * 100}%`).join(",");
      el.style.webkitMaskImage = `linear-gradient(${angle}deg, ${stops})`;
      el.style.maskImage = el.style.webkitMaskImage;
    }
    const colors = Array.isArray(g.color) ? g.color : [];
    const tinted = colors.some(([, c]) => c[0] !== 255 || c[1] !== 255 || c[2] !== 255);
    if (tinted && node.bgT < 1) {
      const stops = colors.map(([t, c]) => `rgb(${c[0]},${c[1]},${c[2]}) ${t * 100}%`).join(",");
      el.style.backgroundImage = `linear-gradient(${angle}deg, ${stops})`;
      el.style.backgroundBlendMode = "multiply";
    }
  }
  if (IMAGE.has(node.c)) {
    el.style.backgroundImage = "repeating-linear-gradient(45deg, rgba(255,255,255,0.08) 0 6px, rgba(0,0,0,0.08) 6px 12px)";
  }
  parentEl.appendChild(el);
  if (TEXT.has(node.c) && node.text) renderText(node, el, w, h, m);
  const content = layoutChildren(node, el, w, h);
  if (node.auto && node.auto !== "None" && !TEXT.has(node.c) && (m.UIListLayout || m.UIGridLayout)) {
    const vertical = m.UIGridLayout ? m.UIGridLayout.dir !== "Vertical" : m.UIListLayout.dir === "Vertical";
    if (vertical && (node.auto === "Y" || node.auto === "XY")) el.style.height = Math.max(h, content.extent + content.pad) + "px";
  }
  return el;
}

// Renders a SurfaceGui/ScreenGui tree into `host` at w x h pixels.
export function renderGui(tree, host, w, h, options = {}) {
  host.innerHTML = "";
  host.style.position = "relative";
  host.style.width = w + "px";
  host.style.height = h + "px";
  host.style.overflow = "hidden";
  if (options.background) host.style.background = options.background;
  const inset = options.inset || 0;
  const root = document.createElement("div");
  root.style.cssText = `position:absolute;left:0;top:${inset}px;width:${w}px;height:${h - inset}px;`;
  host.appendChild(root);
  layoutChildren(tree, root, w, h - inset);
  return host;
}
