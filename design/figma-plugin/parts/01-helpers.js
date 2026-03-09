// ============================================
// PART 1: CONSTANTS & HELPERS
// ============================================

const PHONE_W = 393;
const PHONE_H = 852;
const SCREEN_GAP = 100;

const C = {
  bg:        { r: 0.949, g: 0.949, b: 0.969 },
  card:      { r: 1, g: 1, b: 1 },
  primary:   { r: 0.110, g: 0.110, b: 0.118 },
  secondary: { r: 0.557, g: 0.557, b: 0.577 },
  tertiary:  { r: 0.463, g: 0.463, b: 0.502 },
  accent:    { r: 0, g: 0.478, b: 1 },
  green:     { r: 0.204, g: 0.780, b: 0.349 },
  red:       { r: 1, g: 0.231, b: 0.188 },
  orange:    { r: 1, g: 0.584, b: 0 },
  yellow:    { r: 1, g: 0.800, b: 0 },
  purple:    { r: 0.345, g: 0.337, b: 0.839 },
  pink:      { r: 1, g: 0.176, b: 0.333 },
  border:    { r: 0.898, g: 0.898, b: 0.918 },
  black:     { r: 0, g: 0, b: 0 },
  white:     { r: 1, g: 1, b: 1 },
  dimBg:     { r: 0.118, g: 0.118, b: 0.125 },
};

// Solid fill shorthand
function fill(color, opacity) {
  const f = { type: 'SOLID', color: color };
  if (opacity !== undefined) f.opacity = opacity;
  return [f];
}

// Stroke shorthand
function stroke(color, weight) {
  return { strokes: fill(color), strokeWeight: weight || 1 };
}

// Create a frame with common properties
function createFrame(parent, name, x, y, w, h, options = {}) {
  const f = figma.createFrame();
  f.name = name;
  f.x = x;
  f.y = y;
  f.resize(w, h);
  f.fills = options.fills || fill(options.color || C.bg);
  f.cornerRadius = options.radius || 0;
  if (options.stroke) {
    f.strokes = fill(options.stroke);
    f.strokeWeight = options.strokeWeight || 1;
  }
  if (options.layout) {
    f.layoutMode = options.layout; // 'VERTICAL' or 'HORIZONTAL'
    f.itemSpacing = options.spacing || 0;
    f.paddingLeft = options.padX || options.pad || 0;
    f.paddingRight = options.padX || options.pad || 0;
    f.paddingTop = options.padY || options.pad || 0;
    f.paddingBottom = options.padY || options.pad || 0;
    f.primaryAxisAlignItems = options.mainAlign || 'MIN';
    f.counterAxisAlignItems = options.crossAlign || 'MIN';
    if (options.hug) {
      f.primaryAxisSizingMode = 'AUTO';
      f.counterAxisSizingMode = 'AUTO';
    }
    if (options.fillW) f.counterAxisSizingMode = 'FIXED';
  }
  if (options.clip) f.clipsContent = true;
  if (options.opacity !== undefined) f.opacity = options.opacity;
  parent.appendChild(f);
  return f;
}

// Create text node
function createText(parent, text, x, y, options = {}) {
  const t = figma.createText();
  t.name = options.name || text.substring(0, 30);
  t.x = x;
  t.y = y;
  t.characters = text;
  t.fontSize = options.size || 16;
  t.fills = fill(options.color || C.primary);
  if (options.weight === 'bold') {
    t.fontName = { family: 'Inter', style: 'Bold' };
  } else if (options.weight === 'semi') {
    t.fontName = { family: 'Inter', style: 'Semi Bold' };
  } else if (options.weight === 'medium') {
    t.fontName = { family: 'Inter', style: 'Medium' };
  } else {
    t.fontName = { family: 'Inter', style: 'Regular' };
  }
  if (options.width) {
    t.resize(options.width, t.height);
    t.textAutoResize = 'HEIGHT';
  }
  if (options.align) t.textAlignHorizontal = options.align; // 'LEFT', 'CENTER', 'RIGHT'
  if (options.lineHeight) t.lineHeight = { value: options.lineHeight, unit: 'PIXELS' };
  parent.appendChild(t);
  return t;
}

// Create rectangle
function createRect(parent, name, x, y, w, h, options = {}) {
  const r = figma.createRectangle();
  r.name = name;
  r.x = x;
  r.y = y;
  r.resize(w, h);
  r.fills = options.fills || fill(options.color || C.card);
  r.cornerRadius = options.radius || 0;
  if (options.stroke) {
    r.strokes = fill(options.stroke);
    r.strokeWeight = options.strokeWeight || 1;
  }
  if (options.opacity !== undefined) r.opacity = options.opacity;
  parent.appendChild(r);
  return r;
}

// Create ellipse/circle
function createCircle(parent, name, x, y, size, options = {}) {
  const e = figma.createEllipse();
  e.name = name;
  e.x = x;
  e.y = y;
  e.resize(size, size);
  e.fills = options.fills || fill(options.color || C.accent);
  if (options.stroke) {
    e.strokes = fill(options.stroke);
    e.strokeWeight = options.strokeWeight || 2;
  }
  if (options.arcStart !== undefined) {
    e.arcData = {
      startingAngle: options.arcStart || 0,
      endingAngle: options.arcEnd || 6.28,
      innerRadius: options.innerRadius || 0,
    };
  }
  parent.appendChild(e);
  return e;
}

// Create a line
function createLine(parent, name, x1, y1, x2, y2, options = {}) {
  const l = figma.createLine();
  l.name = name;
  l.x = x1;
  l.y = y1;
  l.resize(Math.abs(x2 - x1) || 0.01, 0);
  l.rotation = -Math.atan2(y2 - y1, x2 - x1) * (180 / Math.PI);
  l.strokes = fill(options.color || C.border);
  l.strokeWeight = options.weight || 1;
  if (options.dash) l.dashPattern = [options.dash, options.dash];
  parent.appendChild(l);
  return l;
}

// ============================================
// COMPOUND COMPONENTS
// ============================================

// iPhone screen frame
function createPhoneFrame(parent, name, x, y) {
  const f = createFrame(parent, name, x, y, PHONE_W, PHONE_H, {
    color: C.bg,
    radius: 44,
    clip: true,
  });
  return f;
}

// Status bar
function addStatusBar(parent) {
  const bar = createFrame(parent, 'Status Bar', 0, 0, PHONE_W, 54, { color: C.bg });
  // Dynamic island
  createRect(bar, 'Dynamic Island', 143, 10, 107, 28, { color: C.black, radius: 14 });
  // Time
  createText(bar, '9:41', 24, 14, { size: 15, weight: 'semi', color: C.primary });
  // Signal dots
  createRect(bar, 'Signal', 320, 20, 16, 12, { color: C.primary, radius: 2 });
  createRect(bar, 'WiFi', 342, 18, 16, 14, { color: C.primary, radius: 2 });
  createRect(bar, 'Battery', 364, 19, 22, 12, { color: C.primary, radius: 3 });
  return bar;
}

// Tab bar (3 tabs: Home, Live, Explore)
function addTabBar(parent, activeTab) {
  const bar = createFrame(parent, 'Tab Bar', 0, PHONE_H - 83, PHONE_W, 83, {
    color: C.card,
  });
  // Top border
  createRect(bar, 'border', 0, 0, PHONE_W, 0.5, { color: C.border });

  const tabs = ['Home', 'Live', 'Explore'];
  const icons = ['house.fill', 'waveform.path', 'chart.bar.fill'];
  const tabW = PHONE_W / 3;

  tabs.forEach((tab, i) => {
    const isActive = tab.toLowerCase() === activeTab;
    const col = isActive ? C.accent : C.secondary;
    const cx = tabW * i + tabW / 2;
    // Icon placeholder
    createRect(bar, `${tab} Icon`, cx - 12, 12, 24, 24, { color: col, radius: 6 });
    // Label
    createText(bar, tab, cx - 16, 40, { size: 10, weight: isActive ? 'semi' : 'medium', color: col, align: 'CENTER', width: 32 });
  });

  // Home indicator
  createRect(bar, 'Home Indicator', 147, 70, 100, 5, { color: C.primary, radius: 3 });
  return bar;
}

// Navigation bar with back button
function addNavBar(parent, title, options = {}) {
  const bar = createFrame(parent, 'Nav Bar', 0, 54, PHONE_W, 44, { color: C.bg });
  // Back button
  if (options.back !== false) {
    createText(bar, '\u2039', 12, 6, { size: 28, weight: 'medium', color: C.accent });
    if (options.backLabel) {
      createText(bar, options.backLabel, 28, 13, { size: 17, color: C.accent });
    }
  }
  // Title
  createText(bar, title, 0, 12, { size: 17, weight: 'semi', color: C.primary, width: PHONE_W, align: 'CENTER' });
  // Right action
  if (options.rightIcon) {
    createRect(bar, options.rightIcon, PHONE_W - 38, 10, 24, 24, { color: C.accent, radius: 6 });
  }
  return bar;
}

// Large title header (for tab root views)
function addLargeTitle(parent, title, y, options = {}) {
  const t = createText(parent, title, 20, y, { size: 34, weight: 'bold', color: C.primary });
  if (options.rightIcon) {
    createRect(parent, options.rightIcon, PHONE_W - 46, y + 4, 28, 28, { color: C.secondary, radius: 8 });
  }
  if (options.rightIcon2) {
    createRect(parent, options.rightIcon2, PHONE_W - 82, y + 4, 28, 28, { color: C.secondary, radius: 8 });
  }
  return t;
}

// Card container
function addCard(parent, name, x, y, w, h, options = {}) {
  const card = createFrame(parent, name, x, y, w, h, {
    color: C.card,
    radius: options.radius || 16,
    stroke: options.stroke,
    strokeWeight: options.strokeWeight,
  });
  if (options.shadow) {
    card.effects = [{
      type: 'DROP_SHADOW',
      color: { r: 0, g: 0, b: 0, a: 0.06 },
      offset: { x: 0, y: 2 },
      radius: 8,
      visible: true,
      blendMode: 'NORMAL',
    }];
  }
  return card;
}

// Section header
function addSectionHeader(parent, title, y, options = {}) {
  createText(parent, title, 20, y, { size: 20, weight: 'semi', color: C.primary });
  if (options.badge) {
    const bx = 20 + title.length * 11;
    createRect(parent, 'badge', bx, y + 2, 36, 20, { color: C.orange, radius: 10 });
    createText(parent, options.badge, bx + 5, y + 4, { size: 11, weight: 'bold', color: C.white });
  }
  if (options.link) {
    createText(parent, options.link, PHONE_W - 80, y + 4, { size: 14, color: C.accent });
  }
}

// Score ring (circular progress)
function addScoreRing(parent, x, y, size, score, options = {}) {
  const g = createFrame(parent, 'Score Ring', x, y, size, size, { fills: [] });
  // Background ring
  createCircle(g, 'ring-bg', 0, 0, size, {
    fills: [],
    stroke: C.border,
    strokeWeight: size * 0.08,
  });
  // Progress ring
  const scoreColor = score >= 80 ? C.green : score >= 60 ? C.yellow : score >= 40 ? C.orange : C.red;
  const endAngle = (score / 100) * 6.28;
  createCircle(g, 'ring-progress', 0, 0, size, {
    fills: [],
    stroke: scoreColor,
    strokeWeight: size * 0.08,
    arcStart: -1.57,
    arcEnd: -1.57 + endAngle,
    innerRadius: 0.85,
  });
  // Score text
  createText(g, String(score), size / 2 - (score >= 100 ? 18 : 12), size / 2 - (size * 0.15), {
    size: size * 0.3,
    weight: 'bold',
    color: C.primary,
  });
  if (options.label) {
    createText(g, options.label, 0, size + 6, {
      size: 12,
      color: C.secondary,
      width: size,
      align: 'CENTER',
    });
  }
  return g;
}

// Badge pill
function addBadge(parent, text, x, y, color, textColor) {
  const w = text.length * 7 + 16;
  createRect(parent, 'badge-bg', x, y, w, 22, { color: color, radius: 11 });
  createText(parent, text, x + 8, y + 4, { size: 11, weight: 'semi', color: textColor || C.white });
}

// Trend arrow badge
function addTrendBadge(parent, direction, value, x, y) {
  const arrow = direction === 'up' ? '\u2191' : direction === 'down' ? '\u2193' : '\u2192';
  const col = direction === 'up' ? C.green : direction === 'down' ? C.red : C.secondary;
  createText(parent, `${arrow} ${value}`, x, y, { size: 13, weight: 'semi', color: col });
}

// Toggle row (iOS settings style)
function addToggleRow(parent, label, isOn, y) {
  createText(parent, label, 16, y + 10, { size: 16, color: C.primary });
  const toggleX = PHONE_W - 67;
  createRect(parent, 'toggle-track', toggleX, y + 8, 51, 31, {
    color: isOn ? C.green : C.border,
    radius: 16,
  });
  createCircle(parent, 'toggle-thumb', isOn ? toggleX + 22 : toggleX + 2, y + 10, 27, {
    color: C.white,
  });
}

// Settings row with chevron
function addSettingsRow(parent, label, detail, y, options = {}) {
  createText(parent, label, 16, y + 12, { size: 16, color: options.destructive ? C.red : C.primary });
  if (detail) {
    createText(parent, detail, PHONE_W - 60, y + 12, { size: 16, color: C.secondary, align: 'RIGHT' });
  }
  if (options.badge) {
    addBadge(parent, options.badge, PHONE_W - 90, y + 10, C.orange, C.white);
  }
  if (options.chevron !== false) {
    createText(parent, '\u203A', PHONE_W - 28, y + 10, { size: 18, color: C.secondary });
  }
  // Divider
  if (!options.last) {
    createRect(parent, 'divider', 16, y + 44, PHONE_W - 32, 0.5, { color: C.border });
  }
}

// Sheet handle bar
function addSheetHandle(parent) {
  createRect(parent, 'Sheet Handle', PHONE_W / 2 - 18, 8, 36, 5, { color: C.border, radius: 3 });
}

// Progress dots
function addProgressDots(parent, total, active, y) {
  const dotSize = 8;
  const gap = 10;
  const totalW = total * dotSize + (total - 1) * gap;
  const startX = (PHONE_W - totalW) / 2;
  for (let i = 0; i < total; i++) {
    createCircle(parent, `dot-${i}`, startX + i * (dotSize + gap), y, dotSize, {
      color: i === active ? C.accent : C.border,
    });
  }
}

// Button
function addButton(parent, label, x, y, w, h, options = {}) {
  const bgColor = options.outlined ? C.bg : (options.color || C.accent);
  const textColor = options.outlined ? (options.color || C.accent) : C.white;
  createRect(parent, `btn-${label}`, x, y, w, h, {
    color: bgColor,
    radius: options.radius || 14,
    stroke: options.outlined ? (options.color || C.accent) : undefined,
    strokeWeight: options.outlined ? 1.5 : undefined,
  });
  createText(parent, label, x, y + (h - 17) / 2, {
    size: options.size || 17,
    weight: 'semi',
    color: textColor,
    width: w,
    align: 'CENTER',
  });
}

// Metric row (for lists)
function addMetricRow(parent, name, value, y, options = {}) {
  createText(parent, name, 16, y + 12, { size: 16, color: C.primary });
  createText(parent, value, PHONE_W - 120, y + 12, {
    size: 16, weight: 'medium', color: C.primary, align: 'RIGHT', width: 80,
  });
  if (options.trend) {
    addTrendBadge(parent, options.trend.dir, options.trend.val, PHONE_W - 32, y + 13);
  }
  if (options.chevron) {
    createText(parent, '\u203A', PHONE_W - 28, y + 10, { size: 18, color: C.secondary });
  }
  if (!options.last) {
    createRect(parent, 'divider', 16, y + 44, PHONE_W - 32, 0.5, { color: C.border });
  }
}

// Semi-circular gauge
function addGauge(parent, x, y, size, value, maxValue) {
  const g = createFrame(parent, 'Gauge', x, y, size, size / 2 + 20, { fills: [] });
  // Background arc segments (green, yellow, orange, red)
  const colors = [C.green, C.yellow, C.orange, C.red];
  const segW = size / 4;
  colors.forEach((col, i) => {
    createRect(g, `seg-${i}`, i * segW, 0, segW - 2, size / 2, { color: col, radius: 4, opacity: 0.3 });
  });
  // Value text
  createText(g, String(value), size / 2 - 16, size / 2 - 30, {
    size: 28, weight: 'bold', color: C.primary, align: 'CENTER', width: 40,
  });
  // Needle indicator
  const needleX = (value / maxValue) * size;
  createRect(g, 'needle', needleX - 2, 0, 4, size / 2 + 5, { color: C.primary, radius: 2 });
  return g;
}

// Insight card
function addInsightCard(parent, x, y, w, severity, category, title, desc) {
  const card = addCard(parent, `insight-${title.substring(0, 20)}`, x, y, w, 100, { shadow: true });
  const sevColor = severity === 'Critical' ? C.red : severity === 'Warning' ? C.orange : C.accent;
  addBadge(card, severity, 12, 12, sevColor);
  if (category) addBadge(card, category, w - category.length * 7 - 28, 12, C.border, C.secondary);
  createText(card, title, 12, 42, { size: 14, weight: 'semi', color: C.primary, width: w - 24 });
  createText(card, desc, 12, 62, { size: 12, color: C.secondary, width: w - 24 });
  return card;
}

// Correlation card
function addCorrelationCard(parent, x, y, w, metric1, metric2, strength, rValue, desc) {
  const card = addCard(parent, `corr-${metric1}-${metric2}`, x, y, w, 90, { shadow: true });
  createText(card, `${metric1}  \u2194  ${metric2}`, 12, 12, { size: 14, weight: 'semi', color: C.primary, width: w - 24 });
  const strColor = strength === 'Strong' ? C.green : strength === 'Moderate' ? C.orange : C.secondary;
  addBadge(card, strength, 12, 36, strColor);
  createText(card, `r = ${rValue}`, 12 + strength.length * 7 + 28, 38, { size: 12, color: C.secondary });
  createText(card, desc, 12, 62, { size: 12, color: C.secondary, width: w - 24 });
  return card;
}

// Action/Recommendation card
function addActionCard(parent, x, y, w, title, desc, options = {}) {
  const card = addCard(parent, `action-${title.substring(0, 20)}`, x, y, w, 76, { shadow: true });
  // Icon circle
  createCircle(card, 'icon', 12, 14, 44, { color: options.iconColor || C.accent, opacity: 0.15 });
  createRect(card, 'icon-inner', 23, 25, 22, 22, { color: options.iconColor || C.accent, radius: 6 });
  // Text
  createText(card, title, 68, 14, { size: 15, weight: 'semi', color: C.primary, width: w - 88 });
  createText(card, desc, 68, 36, { size: 12, color: C.secondary, width: w - 88 });
  // Chevron
  createText(card, '\u203A', w - 24, 24, { size: 18, color: C.secondary });
  return card;
}

// Filter pills row
function addFilterPills(parent, pills, activeIndex, y) {
  let x = 20;
  pills.forEach((label, i) => {
    const isActive = i === activeIndex;
    const w = label.length * 8 + 24;
    createRect(parent, `pill-${label}`, x, y, w, 32, {
      color: isActive ? C.accent : C.bg,
      radius: 16,
      stroke: isActive ? undefined : C.border,
    });
    createText(parent, label, x + 12, y + 8, {
      size: 13, weight: 'semi', color: isActive ? C.white : C.secondary,
    });
    x += w + 8;
  });
}

// Time range selector
function addTimeRangeSelector(parent, activeIndex, y) {
  addFilterPills(parent, ['7d', '30d', '90d', '180d'], activeIndex, y);
}

// Placeholder chart (line chart wireframe)
function addChartPlaceholder(parent, x, y, w, h) {
  const chart = addCard(parent, 'Chart', x, y, w, h, { shadow: true });
  // Grid lines
  for (let i = 0; i < 4; i++) {
    const ly = 20 + i * ((h - 40) / 3);
    createRect(chart, `grid-${i}`, 40, ly, w - 60, 0.5, { color: C.border });
  }
  // Y axis labels
  createText(chart, '80', 8, 16, { size: 10, color: C.secondary });
  createText(chart, '60', 8, 16 + (h - 40) / 3, { size: 10, color: C.secondary });
  createText(chart, '40', 8, 16 + 2 * (h - 40) / 3, { size: 10, color: C.secondary });
  // Baseline dotted line
  createRect(chart, 'baseline', 40, h / 2, w - 60, 1, { color: C.accent, opacity: 0.5 });
  // Normal range shading
  createRect(chart, 'normal-range', 40, h / 2 - 20, w - 60, 40, { color: C.green, opacity: 0.08 });
  // Data line (polyline approximation using rects)
  const points = [0.6, 0.5, 0.55, 0.45, 0.5, 0.4, 0.42, 0.38, 0.35, 0.4, 0.45, 0.42];
  const dataW = (w - 60) / (points.length - 1);
  points.forEach((p, i) => {
    if (i < points.length - 1) {
      const x1 = 40 + i * dataW;
      const y1 = 20 + p * (h - 40);
      createCircle(chart, `dot-${i}`, x1 - 3, y1 - 3, 6, { color: C.accent });
    }
  });
  // X axis labels
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May'];
  months.forEach((m, i) => {
    createText(chart, m, 40 + i * ((w - 60) / 4) - 10, h - 18, { size: 10, color: C.secondary });
  });
  return chart;
}

// Empty/Loading placeholder
function addEmptyState(parent, y, icon, title, subtitle) {
  createRect(parent, 'empty-icon', PHONE_W / 2 - 30, y, 60, 60, { color: C.border, radius: 30 });
  createText(parent, title, 0, y + 76, { size: 18, weight: 'semi', color: C.primary, width: PHONE_W, align: 'CENTER' });
  createText(parent, subtitle, 40, y + 102, { size: 14, color: C.secondary, width: PHONE_W - 80, align: 'CENTER' });
}
