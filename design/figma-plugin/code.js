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
// ============================================
// PART 2: ONBOARDING SCREENS
// ============================================
// Depends on Part 1 helpers: createPhoneFrame, addStatusBar, addTabBar,
// addNavBar, addLargeTitle, addCard, createText, createRect, createCircle,
// addButton, addProgressDots, addBadge, addSheetHandle, fill,
// Constants: C, PHONE_W, PHONE_H, SCREEN_GAP

function createOnboardingScreens(page) {
  const screens = [];
  const gap = PHONE_W + SCREEN_GAP;

  // Screen 1: Welcome
  screens.push(buildWelcomeScreen(page, 0));
  // Screen 2-4: Culture messages
  screens.push(buildCultureScreen1(page, gap));
  screens.push(buildCultureScreen2(page, gap * 2));
  screens.push(buildCultureScreen3(page, gap * 3));
  // Screen 5: HealthKit Permission
  screens.push(buildHealthKitPermissionScreen(page, gap * 4));
  // Screen 6: Focus Selection
  screens.push(buildFocusSelectionScreen(page, gap * 5));
  // Screen 7: Calibration
  screens.push(buildCalibrationScreen(page, gap * 6));
  // Screen 8: Discovery
  screens.push(buildDiscoveryScreen(page, gap * 7));
  // Screen 9: Paywall
  screens.push(buildPaywallScreen(page, gap * 8));

  return screens;
}

// --------------------------------------------------
// Screen 1: Welcome
// --------------------------------------------------
function buildWelcomeScreen(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Welcome", x, 0);
  addStatusBar(phone);

  // App icon — large rounded rect centered
  const iconX = (PHONE_W - 100) / 2;
  const iconRect = createRect(phone, "App Icon", iconX, 220, 100, 100, {
    color: C.accent,
    radius: 24
  });

  // Pulse indicator inside icon
  createRect(phone, "Pulse Line", iconX + 25, 260, 50, 6, {
    color: C.white,
    radius: 3
  });
  createRect(phone, "Pulse Peak", iconX + 45, 248, 6, 30, {
    color: C.white,
    radius: 3
  });

  // App name
  createText(phone, "HealthPulse", 0, 340, {
    size: 32,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "App Name"
  });

  // Tagline
  createText(phone, "Your health, understood.", 0, 380, {
    size: 18,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Tagline"
  });

  // Get Started button
  addButton(phone, "Get Started", 32, 740, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  return phone;
}

// --------------------------------------------------
// Screen 2: Culture 1 — Health is personal
// --------------------------------------------------
function buildCultureScreen1(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Culture 1", x, 0);
  addStatusBar(phone);

  // Illustration placeholder
  const illusX = (PHONE_W - 200) / 2;
  createRect(phone, "Illustration BG", illusX, 160, 200, 200, {
    color: C.accent,
    radius: 24,
    opacity: 0.1
  });

  // Heart icon inside
  const heartCx = PHONE_W / 2;
  createCircle(phone, "Heart Icon", heartCx - 25, 235, 50, {
    color: C.red
  });

  // Headline
  createText(phone, "We believe health\nis personal", 0, 400, {
    size: 26,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Culture Headline"
  });

  // Body text
  createText(phone, "No two bodies are the same. HealthPulse learns\nyour unique patterns, rhythms, and thresholds\nto give you insights that truly matter.", 0, 470, {
    size: 16,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Culture Body"
  });

  // Progress dots
  addProgressDots(phone, 7, 0, 640);

  // Continue button
  addButton(phone, "Continue", 32, 740, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  return phone;
}

// --------------------------------------------------
// Screen 3: Culture 2 — Intelligence that grows
// --------------------------------------------------
function buildCultureScreen2(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Culture 2", x, 0);
  addStatusBar(phone);

  // Illustration placeholder
  const illusX = (PHONE_W - 200) / 2;
  createRect(phone, "Illustration BG", illusX, 160, 200, 200, {
    color: C.accent,
    radius: 24,
    opacity: 0.1
  });

  // Brain icon inside
  const brainCx = PHONE_W / 2;
  createCircle(phone, "Brain Icon", brainCx - 25, 235, 50, {
    color: C.purple
  });

  // Headline
  createText(phone, "Intelligence that\ngrows with you", 0, 400, {
    size: 26,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Culture Headline"
  });

  // Body text
  createText(phone, "Our on-device ML engine learns more every day.\nFrom forecasting trends to detecting anomalies,\nyour insights get smarter over time.", 0, 470, {
    size: 16,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Culture Body"
  });

  // Progress dots
  addProgressDots(phone, 7, 1, 640);

  // Continue button
  addButton(phone, "Continue", 32, 740, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  return phone;
}

// --------------------------------------------------
// Screen 4: Culture 3 — Data stays yours
// --------------------------------------------------
function buildCultureScreen3(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Culture 3", x, 0);
  addStatusBar(phone);

  // Illustration placeholder
  const illusX = (PHONE_W - 200) / 2;
  createRect(phone, "Illustration BG", illusX, 160, 200, 200, {
    color: C.accent,
    radius: 24,
    opacity: 0.1
  });

  // Shield/lock icon inside
  const shieldCx = PHONE_W / 2;
  createCircle(phone, "Shield Icon", shieldCx - 25, 235, 50, {
    color: C.green
  });

  // Headline
  createText(phone, "Your data stays yours", 0, 400, {
    size: 26,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Culture Headline"
  });

  // Body text
  createText(phone, "All analysis runs on your device. Your health\ndata is encrypted at rest and never leaves\nyour phone. No cloud. No compromise.", 0, 470, {
    size: 16,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Culture Body"
  });

  // Progress dots
  addProgressDots(phone, 7, 2, 640);

  // Continue button
  addButton(phone, "Continue", 32, 740, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  return phone;
}

// --------------------------------------------------
// Screen 5: HealthKit Permission
// --------------------------------------------------
function buildHealthKitPermissionScreen(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - HealthKit Permission", x, 0);
  addStatusBar(phone);

  // Apple Health icon — red rounded rect
  const iconX = (PHONE_W - 70) / 2;
  createRect(phone, "Health Icon BG", iconX, 100, 70, 70, {
    color: C.red,
    radius: 16
  });

  // White cross/heart inside icon
  createRect(phone, "Cross H", iconX + 20, 130, 30, 8, {
    color: C.white,
    radius: 2
  });
  createRect(phone, "Cross V", iconX + 31, 118, 8, 30, {
    color: C.white,
    radius: 2
  });

  // Headline
  createText(phone, "Connect Apple Health", 0, 190, {
    size: 24,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "HK Headline"
  });

  // Body text
  createText(phone, "HealthPulse reads your health data to build\npersonalized insights and track your progress.", 0, 230, {
    size: 15,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "HK Body"
  });

  // Permission list
  const permissions = [
    "Heart Rate",
    "Steps",
    "Sleep Analysis",
    "Heart Rate Variability",
    "Blood Oxygen",
    "Workouts",
    "Body Measurements"
  ];

  const listStartY = 290;
  const rowHeight = 44;
  const listPadX = 48;

  permissions.forEach((label, i) => {
    const rowY = listStartY + i * rowHeight;

    // Green checkmark circle
    createCircle(phone, `Check ${label}`, listPadX, rowY + 12, 20, {
      color: C.green
    });

    // Checkmark text inside circle
    createText(phone, "\u2713", listPadX + 4, rowY + 12, {
      size: 12,
      weight: "bold",
      color: C.white,
      name: `CheckMark ${label}`
    });

    // Label text
    createText(phone, label, listPadX + 32, rowY + 14, {
      size: 16,
      weight: "medium",
      color: C.black,
      name: `Perm Label ${label}`
    });
  });

  // Connect button
  addButton(phone, "Connect Health Data", 32, 620, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  // Skip link
  createText(phone, "Skip for now", 0, 688, {
    size: 15,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Skip Link"
  });

  return phone;
}

// --------------------------------------------------
// Screen 6: Focus Selection
// --------------------------------------------------
function buildFocusSelectionScreen(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Focus Selection", x, 0);
  addStatusBar(phone);

  // Headline
  createText(phone, "What matters most?", 0, 80, {
    size: 24,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Focus Headline"
  });

  // Subtitle
  createText(phone, "Choose your focus areas", 0, 115, {
    size: 16,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Focus Subtitle"
  });

  // 2x3 grid of focus cards
  const cards = [
    { label: "Sleep\nQuality",      iconColor: C.purple,  selected: true  },
    { label: "Heart\nHealth",        iconColor: C.red,     selected: false },
    { label: "Fitness",              iconColor: C.orange,  selected: true  },
    { label: "Weight\nManagement",   iconColor: C.green,   selected: false },
    { label: "Stress &\nRecovery",   iconColor: C.accent,  selected: false },
    { label: "Overall\nWellness",    iconColor: C.primary, selected: false }
  ];

  const cardW = 170;
  const cardH = 100;
  const gapH = 12;
  const gapV = 12;
  const gridStartX = (PHONE_W - cardW * 2 - gapH) / 2;
  const gridStartY = 160;

  cards.forEach((card, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const cx = gridStartX + col * (cardW + gapH);
    const cy = gridStartY + row * (cardH + gapV);

    if (card.selected) {
      // Selected card: accent stroke, light accent bg
      createRect(phone, `Focus Card ${i}`, cx, cy, cardW, cardH, {
        color: C.accent,
        radius: 12,
        opacity: 0.08,
        stroke: C.accent
      });
    } else {
      // Unselected card: border stroke, white bg
      createRect(phone, `Focus Card ${i}`, cx, cy, cardW, cardH, {
        color: C.white,
        radius: 12,
        stroke: C.border
      });
    }

    // Icon placeholder circle
    createCircle(phone, `Focus Icon ${i}`, cx + (cardW - 36) / 2, cy + 16, 36, {
      color: card.iconColor
    });

    // Label text
    createText(phone, card.label, cx, cy + 60, {
      size: 13,
      weight: "semibold",
      color: C.black,
      width: cardW,
      align: "CENTER",
      name: `Focus Label ${i}`
    });
  });

  // Selection counter
  createText(phone, "2 selected", 0, 540, {
    size: 15,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Selection Counter"
  });

  // Continue button
  addButton(phone, "Continue", 32, 740, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  return phone;
}

// --------------------------------------------------
// Screen 7: Calibration
// --------------------------------------------------
function buildCalibrationScreen(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Calibration", x, 0);
  addStatusBar(phone);

  // Headline
  createText(phone, "Setting up...", 0, 140, {
    size: 24,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Calibration Headline"
  });

  // Large circular progress ring
  const ringSize = 160;
  const ringCx = (PHONE_W - ringSize) / 2;
  const ringCy = 220;

  // Background ring (full circle, light gray)
  createCircle(phone, "Progress Ring BG", ringCx, ringCy, ringSize, {
    color: C.border,
    innerRadius: 0.85
  });

  // Foreground ring (60% arc, accent)
  createCircle(phone, "Progress Ring Fill", ringCx, ringCy, ringSize, {
    color: C.accent,
    innerRadius: 0.85,
    arcStart: -0.5,
    arcEnd: 0.1
  });

  // Percentage text in center
  createText(phone, "60%", 0, 285, {
    size: 28,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Progress Percent"
  });

  // Progress steps list
  const steps = [
    { text: "\u2713  Importing health data",  color: C.green },
    { text: "\u2713  Building baselines",      color: C.green },
    { text: "\u25D0  Detecting patterns...",   color: C.accent },
    { text: "\u25CB  Generating insights",     color: C.secondary }
  ];

  const stepsStartY = 440;
  const stepHeight = 36;

  steps.forEach((step, i) => {
    createText(phone, step.text, 60, stepsStartY + i * stepHeight, {
      size: 16,
      weight: i < 2 ? "medium" : "regular",
      color: step.color,
      width: 280,
      name: `Step ${i}`
    });
  });

  // Linear progress bar background
  const barX = 32;
  const barY = 600;
  const barW = PHONE_W - 64;
  const barH = 6;
  createRect(phone, "Progress Bar BG", barX, barY, barW, barH, {
    color: C.border,
    radius: 3
  });

  // Linear progress bar fill (60%)
  createRect(phone, "Progress Bar Fill", barX, barY, barW * 0.6, barH, {
    color: C.accent,
    radius: 3
  });

  // Processing text
  createText(phone, "Processing 3 months of data...", 0, 620, {
    size: 14,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Processing Label"
  });

  return phone;
}

// --------------------------------------------------
// Screen 8: Discovery
// --------------------------------------------------
function buildDiscoveryScreen(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Discovery", x, 0);
  addStatusBar(phone);

  // Large stat card
  const cardPad = 20;
  const cardW = PHONE_W - cardPad * 2;
  const cardX = cardPad;
  const cardY = 120;
  const cardH = 200;

  // Card background with accent tint
  createRect(phone, "Stat Card BG", cardX, cardY, cardW, cardH, {
    color: C.accent,
    radius: 20,
    opacity: 0.08
  });

  // Large stat number
  createText(phone, "2,847", 0, cardY + 40, {
    size: 48,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Stat Number"
  });

  // Stat label
  createText(phone, "average daily steps last month", 0, cardY + 100, {
    size: 16,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Stat Label"
  });

  // Trend indicator
  createText(phone, "\u2191 12% from previous month", 0, cardY + 135, {
    size: 14,
    weight: "medium",
    color: C.green,
    width: PHONE_W,
    align: "CENTER",
    name: "Trend Indicator"
  });

  // Page dots
  addProgressDots(phone, 4, 0, 650);

  // Next button
  addButton(phone, "Next", 32, 720, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  // Skip link
  createText(phone, "Skip", 0, 790, {
    size: 15,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Skip Link"
  });

  return phone;
}

// --------------------------------------------------
// Screen 9: Paywall
// --------------------------------------------------
function buildPaywallScreen(page, x) {
  const phone = createPhoneFrame(page, "Onboarding - Paywall", x, 0);
  addStatusBar(phone);

  // Headline
  createText(phone, "Unlock HealthPulse Pro", 0, 70, {
    size: 26,
    weight: "bold",
    color: C.black,
    width: PHONE_W,
    align: "CENTER",
    name: "Paywall Headline"
  });

  // Subtitle
  createText(phone, "Experience the full power of your health data", 0, 105, {
    size: 14,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Paywall Subtitle"
  });

  // Feature list with green checkmarks
  const features = [
    "Real-time vitals streaming",
    "Advanced health correlations",
    "What-if simulation engine",
    "Health state timeline",
    "Data export & sharing"
  ];

  const featStartY = 150;
  const featRowH = 36;
  const featPadX = 48;

  features.forEach((feat, i) => {
    const rowY = featStartY + i * featRowH;

    // Green checkmark circle
    createCircle(phone, `Feat Check ${i}`, featPadX, rowY + 8, 20, {
      color: C.green
    });

    // Checkmark symbol
    createText(phone, "\u2713", featPadX + 4, rowY + 8, {
      size: 12,
      weight: "bold",
      color: C.white,
      name: `Feat CheckMark ${i}`
    });

    // Feature label
    createText(phone, feat, featPadX + 32, rowY + 10, {
      size: 16,
      weight: "medium",
      color: C.black,
      name: `Feat Label ${i}`
    });
  });

  // Pricing cards — two side by side
  const pricingY = 380;
  const pricingCardW = 170;
  const pricingCardH = 120;
  const pricingGap = 12;
  const pricingStartX = (PHONE_W - pricingCardW * 2 - pricingGap) / 2;

  // Monthly card (left, outlined)
  const monthlyX = pricingStartX;
  createRect(phone, "Monthly Card", monthlyX, pricingY, pricingCardW, pricingCardH, {
    color: C.white,
    radius: 14,
    stroke: C.border
  });

  createText(phone, "Monthly", monthlyX, pricingY + 20, {
    size: 14,
    weight: "medium",
    color: C.secondary,
    width: pricingCardW,
    align: "CENTER",
    name: "Monthly Label"
  });

  createText(phone, "$4.99", monthlyX, pricingY + 50, {
    size: 28,
    weight: "bold",
    color: C.black,
    width: pricingCardW,
    align: "CENTER",
    name: "Monthly Price"
  });

  createText(phone, "/month", monthlyX, pricingY + 85, {
    size: 13,
    weight: "regular",
    color: C.secondary,
    width: pricingCardW,
    align: "CENTER",
    name: "Monthly Period"
  });

  // Yearly card (right, filled accent)
  const yearlyX = pricingStartX + pricingCardW + pricingGap;
  createRect(phone, "Yearly Card", yearlyX, pricingY, pricingCardW, pricingCardH, {
    color: C.accent,
    radius: 14
  });

  createText(phone, "Yearly", yearlyX, pricingY + 20, {
    size: 14,
    weight: "medium",
    color: C.white,
    width: pricingCardW,
    align: "CENTER",
    name: "Yearly Label"
  });

  createText(phone, "$29.99", yearlyX, pricingY + 50, {
    size: 28,
    weight: "bold",
    color: C.white,
    width: pricingCardW,
    align: "CENTER",
    name: "Yearly Price"
  });

  createText(phone, "/year", yearlyX, pricingY + 85, {
    size: 13,
    weight: "regular",
    color: C.white,
    width: pricingCardW,
    align: "CENTER",
    name: "Yearly Period"
  });

  // "Save 50%" badge on yearly card
  addBadge(phone, "Save 50%", yearlyX + pricingCardW - 70, pricingY - 10, C.green, C.white);

  // Start Free Trial button
  addButton(phone, "Start Free Trial", 32, 540, 329, 52, {
    color: C.accent,
    radius: 14,
    size: 17
  });

  // Trial disclaimer
  createText(phone, "7-day free trial, then auto-renews", 0, 600, {
    size: 12,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Trial Disclaimer"
  });

  // Restore Purchases link
  createText(phone, "Restore Purchases", 0, 640, {
    size: 14,
    weight: "medium",
    color: C.accent,
    width: PHONE_W,
    align: "CENTER",
    name: "Restore Link"
  });

  // Terms & Privacy links
  createText(phone, "Terms of Service  \u00B7  Privacy Policy", 0, 790, {
    size: 11,
    weight: "regular",
    color: C.secondary,
    width: PHONE_W,
    align: "CENTER",
    name: "Legal Links"
  });

  return phone;
}
// ============================================
// PART 3: HOME TAB SCREENS
// ============================================

function createHomeScreens(page) {
  const screens = [];
  const sx = (i) => i * (PHONE_W + SCREEN_GAP);

  // ------------------------------------------
  // Screen 1: Home Main
  // ------------------------------------------
  const s1 = createPhoneFrame(page, 'Home – Main', sx(0), 0);
  addStatusBar(s1);

  // Greeting + icons
  createText(s1, 'Good morning, Alex', 20, 66, { size: 16, weight: 'semi', color: C.primary });
  createRect(s1, 'Gear Icon', PHONE_W - 52, 62, 28, 28, { color: C.secondary, radius: 8 });
  createRect(s1, 'Journal Icon', PHONE_W - 88, 62, 28, 28, { color: C.secondary, radius: 8 });

  // Recovery Hero Card
  const heroCard = addCard(s1, 'Recovery Hero', 20, 100, 353, 170, { shadow: true });
  createText(heroCard, 'Readiness', 16, 12, { size: 14, weight: 'medium', color: C.secondary });
  addGauge(heroCard, 77, 20, 200, 78, 100);
  createText(heroCard, '78', 145, 60, { size: 42, weight: 'bold', color: C.primary, width: 64, align: 'CENTER' });
  createText(heroCard, 'Ready to Go', 0, 108, { size: 16, weight: 'semi', color: C.green, width: 353, align: 'CENTER' });
  createText(heroCard, 'Your readiness score', 0, 132, { size: 12, color: C.secondary, width: 353, align: 'CENTER' });

  // Vitality + Sleep row
  const vitalCard = addCard(s1, 'Vitality Card', 20, 285, 170, 100, { shadow: true });
  createText(vitalCard, 'Vitality Age', 12, 10, { size: 12, weight: 'medium', color: C.secondary });
  createText(vitalCard, '31', 12, 30, { size: 32, weight: 'bold', color: C.primary });
  createText(vitalCard, 'vs actual 34', 12, 68, { size: 12, color: C.secondary });
  createText(vitalCard, '-3 years', 100, 68, { size: 12, weight: 'semi', color: C.green });

  const sleepCard = addCard(s1, 'Sleep Card', 200, 285, 173, 100, { shadow: true });
  createCircle(sleepCard, 'Moon Icon', 12, 12, 24, { color: C.purple, opacity: 0.2 });
  createCircle(sleepCard, 'Moon Inner', 16, 16, 16, { color: C.purple });
  createText(sleepCard, '7h 24m', 44, 14, { size: 18, weight: 'bold', color: C.primary });
  createText(sleepCard, 'Sleep', 12, 48, { size: 12, weight: 'medium', color: C.secondary });
  addBadge(sleepCard, 'Good', 12, 68, C.green, C.white);

  // Period Summary
  addSectionHeader(s1, 'Last 7 Days', 400);
  const periodCard = addCard(s1, 'Period Summary', 20, 430, 353, 140, { shadow: true });

  // Steps row
  createText(periodCard, 'Steps', 16, 16, { size: 15, color: C.primary });
  createText(periodCard, '\u2191 12%', 280, 16, { size: 14, weight: 'semi', color: C.green });
  createRect(periodCard, 'divider-1', 16, 46, 321, 0.5, { color: C.border });

  // Resting HR row
  createText(periodCard, 'Resting HR', 16, 56, { size: 15, color: C.primary });
  createText(periodCard, '\u2193 3 bpm', 266, 56, { size: 14, weight: 'semi', color: C.green });
  createRect(periodCard, 'divider-2', 16, 86, 321, 0.5, { color: C.border });

  // HRV row
  createText(periodCard, 'HRV', 16, 96, { size: 15, color: C.primary });
  createText(periodCard, '\u2192 stable', 274, 96, { size: 14, weight: 'semi', color: C.secondary });

  addTabBar(s1, 'home');
  screens.push(s1);

  // ------------------------------------------
  // Screen 2: Home Scroll
  // ------------------------------------------
  const s2 = createPhoneFrame(page, 'Home – Scrolled', sx(1), 0);
  addStatusBar(s2);

  // Small scrolled title
  createText(s2, 'Home', 0, 56, { size: 17, weight: 'semi', color: C.primary, width: PHONE_W, align: 'CENTER' });

  // Body Insights
  addSectionHeader(s2, 'Body Insights', 80);

  const weightCard = addCard(s2, 'Weight Trend', 20, 110, 170, 90, { shadow: true });
  createText(weightCard, 'Weight Trend', 12, 10, { size: 12, weight: 'medium', color: C.secondary });
  createText(weightCard, '165.2 lbs', 12, 32, { size: 20, weight: 'bold', color: C.primary });
  createText(weightCard, '\u2193 2 lbs', 12, 62, { size: 13, weight: 'semi', color: C.green });

  const bmiCard = addCard(s2, 'BMI', 200, 110, 173, 90, { shadow: true });
  createText(bmiCard, 'BMI', 12, 10, { size: 12, weight: 'medium', color: C.secondary });
  createText(bmiCard, '23.4', 12, 32, { size: 20, weight: 'bold', color: C.primary });
  addBadge(bmiCard, 'Normal', 12, 62, C.green, C.white);

  // Health Risks
  addSectionHeader(s2, 'Needs Attention', 215);

  // Risk card 1 — Red
  const risk1 = addCard(s2, 'Risk – Elevated HR', 20, 248, 353, 60, { shadow: true });
  createRect(risk1, 'left-border', 0, 0, 4, 60, { color: C.red, radius: 2 });
  createText(risk1, 'Elevated Resting HR', 16, 12, { size: 14, weight: 'semi', color: C.primary });
  addBadge(risk1, 'High', 16, 34, C.red, C.white);

  // Risk card 2 — Orange
  const risk2 = addCard(s2, 'Risk – Sleep', 20, 316, 353, 60, { shadow: true });
  createRect(risk2, 'left-border', 0, 0, 4, 60, { color: C.orange, radius: 2 });
  createText(risk2, 'Sleep Consistency', 16, 12, { size: 14, weight: 'semi', color: C.primary });
  addBadge(risk2, 'Moderate', 16, 34, C.orange, C.white);

  // Risk card 3 — Yellow
  const risk3 = addCard(s2, 'Risk – Activity', 20, 384, 353, 60, { shadow: true });
  createRect(risk3, 'left-border', 0, 0, 4, 60, { color: C.yellow, radius: 2 });
  createText(risk3, 'Activity Decline', 16, 12, { size: 14, weight: 'semi', color: C.primary });
  addBadge(risk3, 'Low', 16, 34, C.yellow, C.primary);

  // Weekly Review
  addSectionHeader(s2, 'Weekly Review', 460);
  const weeklyCard = addCard(s2, 'Weekly Review Card', 20, 490, 353, 80, { shadow: true });
  createText(weeklyCard, 'Score: 74 \u2192 78 (+4)', 16, 12, { size: 15, weight: 'bold', color: C.primary });
  createText(weeklyCard, '3 wins this week', 16, 36, { size: 13, color: C.secondary });
  createText(weeklyCard, 'View Full Review \u203A', 16, 56, { size: 13, weight: 'semi', color: C.accent });

  // Coach Recommendations
  addSectionHeader(s2, 'Coach', 585);
  addActionCard(s2, 20, 615, 353, 'Increase sleep by 30min', 'This could improve your score by 3 points');
  addActionCard(s2, 20, 699, 353, 'Add evening walk', 'Help lower your resting heart rate');

  // Correlations — locked
  addSectionHeader(s2, 'Correlations', 790, { badge: 'PRO' });
  createRect(s2, 'Locked Overlay', 20, 820, 353, 100, { color: C.border, radius: 16, opacity: 0.3 });
  createRect(s2, 'Lock Icon', PHONE_W / 2 - 14, 848, 28, 28, { color: C.secondary, radius: 14 });
  createText(s2, 'Upgrade to unlock', 0, 886, { size: 14, weight: 'semi', color: C.secondary, width: PHONE_W, align: 'CENTER' });

  addTabBar(s2, 'home');
  screens.push(s2);

  // ------------------------------------------
  // Screen 3: Score Guide Sheet
  // ------------------------------------------
  const s3 = createPhoneFrame(page, 'Home – Score Guide', sx(2), 0);
  addSheetHandle(s3);
  createText(s3, 'How Your Score Works', 0, 40, { size: 22, weight: 'bold', color: C.primary, width: PHONE_W, align: 'CENTER' });

  // Score ring
  addScoreRing(s3, PHONE_W / 2 - 50, 80, 100, 78);

  // Category breakdown card
  const catCard = addCard(s3, 'Category Breakdown', 20, 200, 353, 210, { shadow: true });
  const catData = [
    { name: 'Heart',       score: 85, color: C.green },
    { name: 'Sleep',       score: 72, color: C.yellow },
    { name: 'Activity',    score: 68, color: C.orange },
    { name: 'Body',        score: 80, color: C.green },
    { name: 'Respiratory', score: 90, color: C.green },
  ];
  catData.forEach((cat, i) => {
    const ry = 12 + i * 40;
    // Colored dot
    createCircle(catCard, `dot-${cat.name}`, 12, ry + 5, 10, { color: cat.color });
    // Label
    createText(catCard, cat.name, 30, ry + 2, { size: 14, color: C.primary });
    // Score value
    createText(catCard, String(cat.score), 260, ry + 2, { size: 14, weight: 'semi', color: C.primary, width: 30, align: 'RIGHT' });
    // Progress bar background
    createRect(catCard, `bar-bg-${cat.name}`, 298, ry + 4, 40, 10, { color: C.border, radius: 5 });
    // Progress bar fill
    const barW = Math.round((cat.score / 100) * 40);
    createRect(catCard, `bar-${cat.name}`, 298, ry + 4, barW, 10, { color: cat.color, radius: 5 });
    // Divider (except last)
    if (i < catData.length - 1) {
      createRect(catCard, `div-${cat.name}`, 12, ry + 34, 329, 0.5, { color: C.border });
    }
  });

  // Explanation
  createText(s3, 'Each category contributes to your overall health score based on how your metrics compare to your personal baselines and population norms.', 40, 430, {
    size: 14, color: C.secondary, width: PHONE_W - 80, align: 'CENTER', lineHeight: 20,
  });

  // Got it button
  addButton(s3, 'Got it', 40, 740, PHONE_W - 80, 50);
  screens.push(s3);

  // ------------------------------------------
  // Screen 4: Recovery Info Sheet
  // ------------------------------------------
  const s4 = createPhoneFrame(page, 'Home – Recovery Info', sx(3), 0);
  addSheetHandle(s4);
  createText(s4, 'Understanding Readiness', 0, 40, { size: 22, weight: 'bold', color: C.primary, width: PHONE_W, align: 'CENTER' });

  // Gauge illustration
  addGauge(s4, PHONE_W / 2 - 80, 90, 160, 78, 100);

  // What it measures
  createText(s4, 'What it measures', 20, 260, { size: 17, weight: 'semi', color: C.primary });
  createText(s4, 'HRV, resting heart rate, and sleep quality combined into a single recovery indicator.', 20, 286, {
    size: 14, color: C.secondary, width: PHONE_W - 40, lineHeight: 20,
  });

  // How it's calculated
  createText(s4, "How it\u2019s calculated", 20, 340, { size: 17, weight: 'semi', color: C.primary });
  createText(s4, 'Weighted combination of overnight recovery metrics compared against your personal baselines.', 20, 366, {
    size: 14, color: C.secondary, width: PHONE_W - 40, lineHeight: 20,
  });

  // What the levels mean
  createText(s4, 'What the levels mean', 20, 420, { size: 17, weight: 'semi', color: C.primary });
  const levels = [
    { label: 'Excellent', range: '80-100', color: C.green },
    { label: 'Good',      range: '60-79',  color: C.yellow },
    { label: 'Fair',      range: '40-59',  color: C.orange },
    { label: 'Low',       range: '0-39',   color: C.red },
  ];
  levels.forEach((lvl, i) => {
    const ly = 454 + i * 36;
    createCircle(s4, `level-dot-${lvl.label}`, 28, ly + 3, 12, { color: lvl.color });
    createText(s4, lvl.label, 50, ly, { size: 15, color: C.primary });
    createText(s4, lvl.range, 300, ly, { size: 15, weight: 'medium', color: C.secondary, width: 60, align: 'RIGHT' });
  });

  // Got it button
  addButton(s4, 'Got it', 40, 740, PHONE_W - 80, 50);
  screens.push(s4);

  // ------------------------------------------
  // Screen 5: Journal Entry Sheet
  // ------------------------------------------
  const s5 = createPhoneFrame(page, 'Home – Journal Entry', sx(4), 0);
  addSheetHandle(s5);
  createText(s5, 'Quick Log', 20, 30, { size: 22, weight: 'bold', color: C.primary });
  createText(s5, '\u2715', PHONE_W - 44, 30, { size: 22, weight: 'medium', color: C.secondary });

  // Category picker grid (2 rows x 3 cols)
  const catLabels = ['Mood', 'Energy', 'Stress', 'Exercise', 'Nutrition', 'Notes'];
  const catSelected = [true, false, true, false, false, false];
  const gridGap = 8;
  const cellW = 110;
  const cellH = 60;
  catLabels.forEach((label, i) => {
    const col = i % 3;
    const row = Math.floor(i / 3);
    const gx = 20 + col * (cellW + gridGap);
    const gy = 80 + row * (cellH + gridGap);
    const isSel = catSelected[i];
    createRect(s5, `cat-${label}`, gx, gy, cellW, cellH, {
      color: isSel ? C.accent : C.bg,
      radius: 14,
      stroke: isSel ? undefined : C.border,
      strokeWeight: isSel ? undefined : 1.5,
    });
    createText(s5, label, gx, gy + (cellH - 16) / 2, {
      size: 15,
      weight: 'semi',
      color: isSel ? C.white : C.primary,
      width: cellW,
      align: 'CENTER',
    });
  });

  // Intensity
  createText(s5, 'Intensity', 20, 230, { size: 17, weight: 'semi', color: C.primary });
  const intensityLabels = ['1', '2', '3', '4', '5'];
  const activeIntensity = 2; // "3" selected
  const pillW = 56;
  const pillGap = 12;
  const pillStartX = 20;
  intensityLabels.forEach((label, i) => {
    const px = pillStartX + i * (pillW + pillGap);
    const isSel = i === activeIntensity;
    createRect(s5, `intensity-${label}`, px, 262, pillW, 40, {
      color: isSel ? C.accent : C.bg,
      radius: 20,
      stroke: isSel ? undefined : C.border,
      strokeWeight: isSel ? undefined : 1.5,
    });
    createText(s5, label, px, 272, {
      size: 16,
      weight: 'semi',
      color: isSel ? C.white : C.primary,
      width: pillW,
      align: 'CENTER',
    });
  });

  // Notes field
  createText(s5, 'Notes (optional)', 20, 330, { size: 17, weight: 'semi', color: C.primary });
  createRect(s5, 'Notes Field', 20, 360, 353, 120, { color: C.bg, radius: 14, stroke: C.border, strokeWeight: 1 });
  createText(s5, 'Add any notes...', 32, 376, { size: 15, color: C.tertiary });

  // Save button
  addButton(s5, 'Save Entry', 40, 620, PHONE_W - 80, 50);
  screens.push(s5);

  // ------------------------------------------
  // Screen 6: Journal Insights
  // ------------------------------------------
  const s6 = createPhoneFrame(page, 'Home – Journal Insights', sx(5), 0);
  addStatusBar(s6);
  addNavBar(s6, 'Journal Insights');

  // Summary card
  const summaryCard = addCard(s6, 'Summary', 20, 110, 353, 60, { shadow: true });
  summaryCard.fills = fill(C.bg);
  createText(summaryCard, '12 entries this month', 0, 20, {
    size: 15, weight: 'medium', color: C.secondary, width: 353, align: 'CENTER',
  });

  // Insight cards
  const ji1 = addCard(s6, 'Insight – Stress Sleep', 20, 190, 353, 80, { shadow: true });
  createCircle(ji1, 'corr-icon', 12, 18, 40, { color: C.accent, opacity: 0.15 });
  createRect(ji1, 'corr-icon-inner', 22, 28, 20, 20, { color: C.accent, radius: 6 });
  createText(ji1, 'High stress \u2192 23% less sleep', 64, 16, { size: 14, weight: 'semi', color: C.primary, width: 230 });
  addBadge(ji1, 'High', 64, 44, C.green, C.white);

  const ji2 = addCard(s6, 'Insight – Exercise HRV', 20, 280, 353, 80, { shadow: true });
  createCircle(ji2, 'corr-icon', 12, 18, 40, { color: C.accent, opacity: 0.15 });
  createRect(ji2, 'corr-icon-inner', 22, 28, 20, 20, { color: C.accent, radius: 6 });
  createText(ji2, 'Exercise \u2192 15% better HRV', 64, 16, { size: 14, weight: 'semi', color: C.primary, width: 230 });
  addBadge(ji2, 'High', 64, 44, C.green, C.white);

  const ji3 = addCard(s6, 'Insight – Sleep Steps', 20, 370, 353, 80, { shadow: true });
  createCircle(ji3, 'corr-icon', 12, 18, 40, { color: C.accent, opacity: 0.15 });
  createRect(ji3, 'corr-icon-inner', 22, 28, 20, 20, { color: C.accent, radius: 6 });
  createText(ji3, 'Poor sleep \u2192 18% lower steps next day', 64, 16, { size: 14, weight: 'semi', color: C.primary, width: 250 });
  addBadge(ji3, 'Medium', 64, 44, C.yellow, C.primary);

  // Empty state note
  createText(s6, 'Keep logging to discover more patterns', 0, 500, {
    size: 14, color: C.secondary, width: PHONE_W, align: 'CENTER',
  });

  // No tab bar (pushed view)
  screens.push(s6);

  // ------------------------------------------
  // Screen 7: Vitality Detail
  // ------------------------------------------
  const s7 = createPhoneFrame(page, 'Home – Vitality Detail', sx(6), 0);
  addStatusBar(s7);
  addNavBar(s7, 'Vitality Age');

  // Hero score ring
  addScoreRing(s7, PHONE_W / 2 - 70, 110, 140, 31);
  createText(s7, '3 years younger', 0, 262, { size: 16, weight: 'bold', color: C.green, width: PHONE_W, align: 'CENTER' });
  createText(s7, 'than your actual age of 34', 0, 284, { size: 14, color: C.secondary, width: PHONE_W, align: 'CENTER' });

  // Metric breakdown
  addSectionHeader(s7, 'Breakdown', 320);
  const bdCard = addCard(s7, 'Breakdown Card', 20, 350, 353, 190, { shadow: true });

  const bdRows = [
    { name: 'Resting HR', value: '62 bpm (exp. 68)',  delta: '-2.0 yrs', color: C.green },
    { name: 'VO2 Max',    value: '42 (exp. 38)',      delta: '-1.5 yrs', color: C.green },
    { name: 'HRV',        value: '48ms (exp. 40)',     delta: '-1.0 yrs', color: C.green },
    { name: 'BMI',        value: '25.1 (exp. 23.5)',   delta: '+0.5 yrs', color: C.orange },
  ];
  bdRows.forEach((row, i) => {
    const ry = 12 + i * 44;
    createText(bdCard, row.name, 16, ry, { size: 14, weight: 'semi', color: C.primary });
    createText(bdCard, row.value, 16, ry + 20, { size: 12, color: C.secondary });
    createText(bdCard, row.delta, 280, ry + 8, { size: 14, weight: 'semi', color: row.color, width: 60, align: 'RIGHT' });
    if (i < bdRows.length - 1) {
      createRect(bdCard, `div-bd-${i}`, 16, ry + 40, 321, 0.5, { color: C.border });
    }
  });

  // Chart placeholder
  addChartPlaceholder(s7, 20, 560, 353, 120);

  // Improvement Opportunities
  addSectionHeader(s7, 'Improvement Opportunities', 700);
  addActionCard(s7, 20, 730, 353, 'Lower BMI', 'Reducing BMI by 1.5 could improve vitality by 0.5 years');

  // No tab bar (pushed view)
  screens.push(s7);

  return screens;
}
// ============================================
// PART 4: LIVE + EXPLORE TAB SCREENS
// ============================================
// Depends on Part 1 helpers: createPhoneFrame, addStatusBar, addTabBar,
// addLargeTitle, addCard, createText, createRect, createCircle,
// addButton, addBadge, addTrendBadge, addSheetHandle, addTimeRangeSelector,
// addSectionHeader, addScoreRing, addCorrelationCard, fill,
// Constants: C, PHONE_W, PHONE_H, SCREEN_GAP

function createLiveScreens(page) {
  const screens = [];
  const gap = PHONE_W + SCREEN_GAP;

  screens.push(buildLiveMain(page, 0));
  screens.push(buildLiveProOverlay(page, gap));
  screens.push(buildLiveEmpty(page, gap * 2));

  return screens;
}

function createExploreScreens(page) {
  const screens = [];
  const gap = PHONE_W + SCREEN_GAP;

  screens.push(buildExploreMain(page, 0));
  screens.push(buildExploreScroll(page, gap));
  screens.push(buildSimulationSheet(page, gap * 2));

  return screens;
}

// --------------------------------------------------
// Screen 1: Live Main
// --------------------------------------------------
function buildLiveMain(page, x) {
  const phone = createPhoneFrame(page, 'Live - Main', x, 0);
  addStatusBar(phone);

  // Large title
  addLargeTitle(phone, 'Live', 62);

  // Green dot indicating connected
  createCircle(phone, 'Live Dot', 70, 72, 10, { color: C.green });

  // ---- Heart Rate Hero Card ----
  const hrCard = addCard(phone, 'Heart Rate Card', 20, 100, 353, 180, { shadow: true });

  createText(hrCard, 'Heart Rate', 16, 14, { size: 14, color: C.secondary });

  // Small red heart icon top-right
  createCircle(hrCard, 'Heart Icon', 321, 14, 16, { color: C.red });

  // Large BPM number
  createText(hrCard, '72', 120, 45, { size: 56, weight: 'bold', color: C.primary });

  // BPM label
  createText(hrCard, 'BPM', 210, 72, { size: 18, color: C.secondary });

  // Resting badge
  addBadge(hrCard, 'Resting', 140, 112, C.green, C.white);

  // ECG waveform approximation — zigzag pattern of small rects
  const ecgY = 150;
  const ecgPoints = [
    { x: 16, w: 40, h: 2, dy: 0 },
    { x: 56, w: 3, h: 8, dy: -3 },
    { x: 62, w: 3, h: 20, dy: -14 },
    { x: 68, w: 3, h: 28, dy: -4 },
    { x: 74, w: 3, h: 14, dy: -8 },
    { x: 80, w: 40, h: 2, dy: 0 },
    { x: 120, w: 3, h: 6, dy: -2 },
    { x: 126, w: 40, h: 2, dy: 0 },
    { x: 166, w: 3, h: 8, dy: -3 },
    { x: 172, w: 3, h: 20, dy: -14 },
    { x: 178, w: 3, h: 28, dy: -4 },
    { x: 184, w: 3, h: 14, dy: -8 },
    { x: 190, w: 40, h: 2, dy: 0 },
    { x: 230, w: 3, h: 6, dy: -2 },
    { x: 236, w: 60, h: 2, dy: 0 },
    { x: 296, w: 3, h: 8, dy: -3 },
    { x: 302, w: 3, h: 20, dy: -14 },
    { x: 308, w: 3, h: 28, dy: -4 },
    { x: 314, w: 3, h: 14, dy: -8 },
    { x: 320, w: 20, h: 2, dy: 0 },
  ];
  ecgPoints.forEach((p, i) => {
    createRect(hrCard, `ecg-${i}`, p.x, ecgY + p.dy, p.w, p.h, {
      color: C.red,
      radius: 1,
      opacity: 0.6,
    });
  });

  // ---- Vital Signs Row ----
  // SpO2 card
  const spo2Card = addCard(phone, 'SpO2 Card', 20, 295, 170, 90, { shadow: true });
  createText(spo2Card, 'SpO2', 12, 10, { size: 14, color: C.secondary });
  createText(spo2Card, '98%', 12, 32, { size: 28, weight: 'bold', color: C.primary });
  createText(spo2Card, 'Normal', 12, 66, { size: 12, weight: 'semi', color: C.green });
  // Small progress ring
  addScoreRing(spo2Card, 120, 18, 50, 98);

  // Respiratory card
  const respCard = addCard(phone, 'Resp Card', 198, 295, 175, 90, { shadow: true });
  createText(respCard, 'Resp. Rate', 12, 10, { size: 14, color: C.secondary });
  createText(respCard, '16', 12, 32, { size: 28, weight: 'bold', color: C.primary });
  createText(respCard, 'br/min', 52, 42, { size: 14, color: C.secondary });
  createText(respCard, 'Normal', 12, 66, { size: 12, weight: 'semi', color: C.green });

  // ---- Activity Rings Card ----
  const actCard = addCard(phone, 'Activity Rings Card', 20, 400, 353, 140, { shadow: true });
  createText(actCard, 'Activity', 12, 10, { size: 14, color: C.secondary });

  // Concentric ring arcs — centered left area
  const ringCx = 90;
  const ringCy = 45;

  // Outer ring (Move) — red, ~75%
  createCircle(actCard, 'Move Ring BG', ringCx - 50, ringCy - 50, 100, {
    fills: [],
    stroke: C.red,
    strokeWeight: 8,
    arcStart: -1.57,
    arcEnd: -1.57 + 6.28,
    innerRadius: 0.85,
  });
  createCircle(actCard, 'Move Ring BG Dim', ringCx - 50, ringCy - 50, 100, {
    color: C.red,
    opacity: 0.15,
  });
  createCircle(actCard, 'Move Ring', ringCx - 50, ringCy - 50, 100, {
    fills: [],
    stroke: C.red,
    strokeWeight: 8,
    arcStart: -1.57,
    arcEnd: -1.57 + 4.71,
    innerRadius: 0.85,
  });

  // Middle ring (Exercise) — green, ~50%
  createCircle(actCard, 'Exercise Ring BG', ringCx - 35, ringCy - 35, 70, {
    color: C.green,
    opacity: 0.15,
  });
  createCircle(actCard, 'Exercise Ring', ringCx - 35, ringCy - 35, 70, {
    fills: [],
    stroke: C.green,
    strokeWeight: 8,
    arcStart: -1.57,
    arcEnd: -1.57 + 3.14,
    innerRadius: 0.85,
  });

  // Inner ring (Stand) — accent, ~90%
  createCircle(actCard, 'Stand Ring BG', ringCx - 20, ringCy - 20, 40, {
    color: C.accent,
    opacity: 0.15,
  });
  createCircle(actCard, 'Stand Ring', ringCx - 20, ringCy - 20, 40, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 8,
    arcStart: -1.57,
    arcEnd: -1.57 + 5.65,
    innerRadius: 0.85,
  });

  // Labels on right side
  createText(actCard, 'Move: 420/500 cal', 170, 42, { size: 13, weight: 'medium', color: C.red });
  createText(actCard, 'Exercise: 15/30 min', 170, 66, { size: 13, weight: 'medium', color: C.green });
  createText(actCard, 'Stand: 9/12 hr', 170, 90, { size: 13, weight: 'medium', color: C.accent });

  // ---- BP + Temp Row ----
  // Blood Pressure card
  const bpCard = addCard(phone, 'BP Card', 20, 555, 170, 80, { shadow: true });
  createText(bpCard, 'Blood Pressure', 12, 8, { size: 12, color: C.secondary });
  createText(bpCard, '120/80', 12, 28, { size: 22, weight: 'bold', color: C.primary });
  createText(bpCard, 'mmHg', 120, 36, { size: 12, color: C.secondary });
  addBadge(bpCard, 'Normal', 12, 56, C.green, C.white);

  // Temperature card
  const tempCard = addCard(phone, 'Temp Card', 198, 555, 175, 80, { shadow: true });
  createText(tempCard, 'Temperature', 12, 8, { size: 12, color: C.secondary });
  createText(tempCard, '36.6\u00B0', 12, 28, { size: 22, weight: 'bold', color: C.primary });
  createText(tempCard, 'Normal', 12, 56, { size: 12, weight: 'semi', color: C.green });

  // ---- Last Workout Card ----
  const workoutCard = addCard(phone, 'Last Workout Card', 20, 650, 353, 70, { shadow: true });
  createText(workoutCard, 'Last Workout', 12, 8, { size: 12, color: C.secondary });
  createText(workoutCard, 'Running \u2014 32 min', 12, 26, { size: 15, weight: 'bold', color: C.primary });
  createText(workoutCard, '245 cal \u00B7 Today, 7:30 AM', 12, 48, { size: 13, color: C.secondary });

  // ---- Status Footer ----
  createCircle(phone, 'Status Dot', 20, 738, 8, { color: C.green });
  createText(phone, 'Apple Watch connected', 34, 734, { size: 12, color: C.secondary });
  createText(phone, 'Last sync: Just now', 240, 734, { size: 12, color: C.secondary, align: 'RIGHT', width: 133 });

  // Tab bar
  addTabBar(phone, 'live');

  return phone;
}

// --------------------------------------------------
// Screen 2: Live PRO Overlay
// --------------------------------------------------
function buildLiveProOverlay(page, x) {
  const phone = createPhoneFrame(page, 'Live - PRO Overlay', x, 0);
  addStatusBar(phone);

  // Build same content as Live Main but at low opacity
  const dimContent = createFrame(phone, 'Dimmed Content', 0, 54, PHONE_W, PHONE_H - 54, {
    fills: [],
    opacity: 0.2,
  });

  // Simplified dimmed background content
  addLargeTitle(dimContent, 'Live', 8);
  createCircle(dimContent, 'Live Dot', 70, 18, 10, { color: C.green });

  // Dimmed HR card
  const hrDim = addCard(dimContent, 'HR Card Dim', 20, 46, 353, 180, { shadow: true });
  createText(hrDim, 'Heart Rate', 16, 14, { size: 14, color: C.secondary });
  createText(hrDim, '72', 120, 45, { size: 56, weight: 'bold', color: C.primary });
  createText(hrDim, 'BPM', 210, 72, { size: 18, color: C.secondary });

  // Dimmed vital cards
  addCard(dimContent, 'SpO2 Dim', 20, 241, 170, 90, { shadow: true });
  addCard(dimContent, 'Resp Dim', 198, 241, 175, 90, { shadow: true });
  addCard(dimContent, 'Activity Dim', 20, 346, 353, 140, { shadow: true });

  // Dark scrim overlay
  createRect(phone, 'Scrim', 0, 0, PHONE_W, PHONE_H, {
    color: C.black,
    opacity: 0.4,
  });

  // PRO overlay card
  const overlay = addCard(phone, 'PRO Overlay', 47, 200, 300, 420, {
    shadow: true,
    radius: 24,
  });

  // Lock icon
  createRect(overlay, 'Lock Icon', 130, 30, 40, 40, {
    color: C.secondary,
    radius: 20,
  });

  // Title
  createText(overlay, 'Real-time Vitals', 0, 85, {
    size: 22,
    weight: 'bold',
    color: C.primary,
    width: 300,
    align: 'CENTER',
  });

  // Description
  createText(overlay, 'Unlock live health monitoring\nwith HealthPulse Pro', 20, 115, {
    size: 14,
    color: C.secondary,
    width: 260,
    align: 'CENTER',
  });

  // Feature list with green checkmarks
  const features = [
    'Live heart rate monitoring',
    'Blood oxygen tracking',
    'Activity ring progress',
    'Blood pressure updates',
  ];

  features.forEach((feat, i) => {
    const fy = 170 + i * 34;

    // Green checkmark circle
    createCircle(overlay, `Check ${i}`, 30, fy, 20, { color: C.green });
    createText(overlay, '\u2713', 34, fy, { size: 12, weight: 'bold', color: C.white });

    // Feature text
    createText(overlay, feat, 60, fy + 2, { size: 14, color: C.primary });
  });

  // Upgrade button
  addButton(overlay, 'Upgrade to Pro', 20, 320, 260, 48, { color: C.accent });

  // Price label
  createText(overlay, 'Starting at $4.99/mo', 0, 380, {
    size: 12,
    color: C.secondary,
    width: 300,
    align: 'CENTER',
  });

  // Tab bar (on top of scrim)
  addTabBar(phone, 'live');

  return phone;
}

// --------------------------------------------------
// Screen 3: Live Empty
// --------------------------------------------------
function buildLiveEmpty(page, x) {
  const phone = createPhoneFrame(page, 'Live - Empty', x, 0);
  addStatusBar(phone);

  // Large title
  addLargeTitle(phone, 'Live', 62);

  // Gray dot (disconnected)
  createCircle(phone, 'Offline Dot', 70, 72, 10, { color: C.secondary });

  // Watch icon placeholder
  const watchX = (PHONE_W - 100) / 2;
  const watchY = 260;

  // Watch body
  createRect(phone, 'Watch Body', watchX, watchY, 100, 120, {
    color: C.border,
    radius: 24,
  });

  // Watch screen
  createRect(phone, 'Watch Screen', watchX + 12, watchY + 16, 76, 88, {
    color: C.white,
    radius: 16,
  });

  // Watch crown on right side
  createRect(phone, 'Watch Crown', watchX + 100, watchY + 40, 8, 24, {
    color: C.border,
    radius: 4,
  });

  // Pulse circle hint on watch face
  createCircle(phone, 'Watch Pulse', watchX + 32, watchY + 40, 36, {
    color: C.accent,
    opacity: 0.2,
  });

  // Concentric pulse circles radiating outward
  const pulseCx = PHONE_W / 2 - 70;
  const pulseCy = watchY + 60 - 70;
  createCircle(phone, 'Pulse 1', pulseCx + 40, pulseCy + 40, 60, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 2,
    opacity: 0.3,
  });
  createCircle(phone, 'Pulse 2', pulseCx + 20, pulseCy + 20, 100, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 1.5,
    opacity: 0.15,
  });
  createCircle(phone, 'Pulse 3', pulseCx, pulseCy, 140, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 1,
    opacity: 0.05,
  });

  // Waiting text
  createText(phone, 'Waiting for data...', 0, 450, {
    size: 20,
    weight: 'semi',
    color: C.primary,
    width: PHONE_W,
    align: 'CENTER',
  });

  createText(phone, 'Wear your Apple Watch to see\nreal-time vitals', 56, 480, {
    size: 14,
    color: C.secondary,
    width: 280,
    align: 'CENTER',
  });

  // Tab bar
  addTabBar(phone, 'live');

  return phone;
}

// --------------------------------------------------
// Screen 4: Explore Main
// --------------------------------------------------
function buildExploreMain(page, x) {
  const phone = createPhoneFrame(page, 'Explore - Main', x, 0);
  addStatusBar(phone);

  // Large title
  addLargeTitle(phone, 'Explore', 62);

  // Time range selector
  addTimeRangeSelector(phone, 1, 100);

  // ---- Score Hero Card ----
  const scoreCard = addCard(phone, 'Score Hero Card', 20, 145, 353, 160, { shadow: true });

  // Score ring inside card
  addScoreRing(scoreCard, 120, 15, 100, 78);

  // Labels right of ring
  createText(scoreCard, 'Health Score', 230, 35, { size: 20, weight: 'bold', color: C.primary });
  createText(scoreCard, '+4 from last week', 230, 62, { size: 14, color: C.green });
  addBadge(scoreCard, 'Good', 230, 86, C.green, C.white);

  // ---- Data Summary Bar ----
  const summaryCard = addCard(phone, 'Data Summary', 20, 320, 353, 44, {
    stroke: C.border,
    strokeWeight: 1,
  });

  // 3 evenly spaced items
  const sumItems = [
    { bold: '142', label: 'days' },
    { bold: '12', label: 'metrics' },
    { bold: '847', label: 'points' },
  ];
  const sumItemW = 353 / 3;
  sumItems.forEach((item, i) => {
    const ix = i * sumItemW;
    createText(summaryCard, item.bold, ix, 6, {
      size: 15,
      weight: 'bold',
      color: C.primary,
      width: sumItemW,
      align: 'CENTER',
    });
    createText(summaryCard, item.label, ix, 24, {
      size: 11,
      color: C.secondary,
      width: sumItemW,
      align: 'CENTER',
    });
    // Vertical divider between items
    if (i < 2) {
      createRect(summaryCard, `div-${i}`, ix + sumItemW - 0.5, 8, 1, 28, { color: C.border });
    }
  });

  // ---- Trends Section ----
  addSectionHeader(phone, 'Trends', 380);

  const trendData = [
    { metric: 'HRV', dir: 'up', val: '+8%' },
    { metric: 'Resting HR', dir: 'down', val: '-3%' },
    { metric: 'Steps', dir: 'stable', val: 'stable' },
  ];

  trendData.forEach((t, i) => {
    const ty = 410 + i * 56;
    const tCard = addCard(phone, `Trend ${t.metric}`, 20, ty, 353, 48, { shadow: true });
    createText(tCard, t.metric, 16, 14, { size: 15, weight: 'medium', color: C.primary });
    // Trend badge for "down" Resting HR should be green (improvement)
    if (t.metric === 'Resting HR') {
      createText(tCard, '\u2193 -3%', 290, 15, { size: 13, weight: 'semi', color: C.green });
    } else {
      addTrendBadge(tCard, t.dir, t.val, 290, 15);
    }
  });

  // ---- Declining Section ----
  addSectionHeader(phone, 'Declining', 580);

  // Orange indicator dot next to header
  createCircle(phone, 'Declining Dot', 110, 586, 8, { color: C.orange });

  // Two small declining cards
  const decl1 = addCard(phone, 'Declining Sleep', 20, 610, 170, 48, { shadow: true });
  createText(decl1, 'Sleep Duration', 10, 8, { size: 12, weight: 'medium', color: C.primary });
  createText(decl1, '\u2193 12%', 10, 27, { size: 13, weight: 'semi', color: C.red });

  const decl2 = addCard(phone, 'Declining VO2', 198, 610, 175, 48, { shadow: true });
  createText(decl2, 'VO2 Max', 10, 8, { size: 12, weight: 'medium', color: C.primary });
  createText(decl2, '\u2193 5%', 10, 27, { size: 13, weight: 'semi', color: C.orange });

  // Tab bar
  addTabBar(phone, 'explore');

  return phone;
}

// --------------------------------------------------
// Screen 5: Explore Scroll (Correlations + Categories)
// --------------------------------------------------
function buildExploreScroll(page, x) {
  const phone = createPhoneFrame(page, 'Explore - Scroll', x, 0);
  addStatusBar(phone);

  // Scrolled small title
  addNavBar(phone, 'Explore', { back: false });

  // ---- Correlations Preview ----
  addSectionHeader(phone, 'Correlations', 70, { badge: 'PRO' });

  addCorrelationCard(phone, 20, 105, 353, 'Sleep Duration', 'HRV', 'Strong', '0.72',
    'Longer sleep leads to higher next-day HRV');

  addCorrelationCard(phone, 20, 205, 353, 'Steps', 'Resting HR', 'Moderate', '-0.48',
    'More steps correlates with lower heart rate');

  // View All link
  createText(phone, 'View All \u2192', PHONE_W - 100, 305, {
    size: 14,
    weight: 'semi',
    color: C.accent,
  });

  // ---- Health State Card ----
  const hsCard = addCard(phone, 'Health State Card', 20, 330, 353, 64, { shadow: true });

  // Calendar icon
  createRect(hsCard, 'Calendar Icon', 12, 16, 24, 24, {
    color: C.purple,
    radius: 6,
  });

  createText(hsCard, 'Health State Timeline', 48, 12, {
    size: 15,
    weight: 'bold',
    color: C.primary,
  });

  createText(hsCard, 'See your ML health states \u203A', 48, 36, {
    size: 13,
    color: C.secondary,
  });

  // Chevron
  createText(hsCard, '\u203A', 330, 22, { size: 18, color: C.secondary });

  // ---- Categories Grid ----
  addSectionHeader(phone, 'Categories', 410);

  const categories = [
    { name: 'Heart', score: 85, color: C.green },
    { name: 'Sleep', score: 72, color: C.yellow },
    { name: 'Activity', score: 68, color: C.orange },
    { name: 'Body', score: 80, color: C.green },
    { name: 'Respiratory', score: 90, color: C.green },
    { name: 'Mindfulness', score: 65, color: C.orange },
    { name: 'Mobility', score: 74, color: C.yellow },
  ];

  const catCardW = 170;
  const catCardH = 80;
  const catGapH = 13;
  const catGapV = 10;
  const catStartX = 20;
  const catStartY = 440;

  categories.forEach((cat, i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const cx = catStartX + col * (catCardW + catGapH);
    const cy = catStartY + row * (catCardH + catGapV);

    const catCard = addCard(phone, `Cat ${cat.name}`, cx, cy, catCardW, catCardH, { shadow: true });

    // Small score ring
    addScoreRing(catCard, 12, 12, 36, cat.score);

    // Category name
    createText(catCard, cat.name, 60, 18, {
      size: 14,
      weight: 'semi',
      color: C.primary,
    });

    // Score value
    createText(catCard, String(cat.score), 60, 42, {
      size: 16,
      weight: 'bold',
      color: C.primary,
    });
  });

  // Tab bar
  addTabBar(phone, 'explore');

  return phone;
}

// --------------------------------------------------
// Screen 6: Simulation Sheet (What If?)
// --------------------------------------------------
function buildSimulationSheet(page, x) {
  const phone = createPhoneFrame(page, 'Explore - Simulation', x, 0);

  // White background for sheet
  createRect(phone, 'Sheet BG', 0, 0, PHONE_W, PHONE_H, {
    color: C.card,
    radius: 44,
  });

  // Sheet handle
  addSheetHandle(phone);

  // Title row
  createText(phone, 'What If?', 20, 30, { size: 22, weight: 'bold', color: C.primary });

  // Beaker icon placeholder
  createRect(phone, 'Beaker Icon', 120, 32, 22, 22, {
    color: C.purple,
    radius: 6,
  });

  // Reset link
  createText(phone, 'Reset', PHONE_W - 68, 36, {
    size: 15,
    weight: 'semi',
    color: C.accent,
  });

  // ---- Score Comparison ----
  // Current score ring
  addScoreRing(phone, 60, 80, 90, 78, { label: 'Current' });

  // Arrow between
  createText(phone, '\u2192', 175, 110, {
    size: 24,
    weight: 'bold',
    color: C.secondary,
  });

  // Predicted score ring
  addScoreRing(phone, 240, 80, 90, 84, { label: 'Predicted' });

  // +6 points badge centered below
  addBadge(phone, '+6 points', 155, 195, C.green, C.white);

  // ---- Best ROI Section ----
  addSectionHeader(phone, 'Best ROI', 230);

  const roi1 = addCard(phone, 'ROI Sleep', 20, 260, 353, 60, { shadow: true });
  createText(roi1, '+30 min sleep', 16, 20, { size: 15, weight: 'medium', color: C.primary });
  addBadge(roi1, '+3 pts', 280, 18, C.green, C.white);

  const roi2 = addCard(phone, 'ROI Steps', 20, 328, 353, 60, { shadow: true });
  createText(roi2, '+2,000 steps', 16, 20, { size: 15, weight: 'medium', color: C.primary });
  addBadge(roi2, '+2 pts', 280, 18, C.green, C.white);

  // ---- Metric Sliders Section ----
  addSectionHeader(phone, 'Adjust Metrics', 400);

  const sliders = [
    { label: 'Sleep Duration', current: '7.4h', target: '8.0h' },
    { label: 'Steps', current: '6,500', target: '8,500' },
    { label: 'HRV', current: '45ms', target: '52ms' },
    { label: 'Resting HR', current: '68bpm', target: '64bpm' },
  ];

  sliders.forEach((s, i) => {
    const sy = 432 + i * 60;

    // Label
    createText(phone, s.label, 20, sy, { size: 13, weight: 'semi', color: C.primary });

    // Current value
    createText(phone, s.current, 20, sy + 22, { size: 12, color: C.secondary });

    // Slider track
    createRect(phone, `Track ${s.label}`, 90, sy + 28, 200, 4, {
      color: C.border,
      radius: 2,
    });

    // Slider fill (progress portion)
    const fillW = i === 3 ? 130 : 120 + i * 20; // Varying positions
    createRect(phone, `Fill ${s.label}`, 90, sy + 28, fillW, 4, {
      color: C.accent,
      radius: 2,
    });

    // Thumb circle
    createCircle(phone, `Thumb ${s.label}`, 90 + fillW - 10, sy + 20, 20, {
      color: C.accent,
    });

    // Target value
    createText(phone, s.target, 300, sy + 22, {
      size: 12,
      weight: 'medium',
      color: C.accent,
    });
  });

  // ---- Impact by Category ----
  createText(phone, 'Impact by Category', 20, 680, {
    size: 15,
    weight: 'semi',
    color: C.primary,
  });

  const impacts = [
    { cat: 'Heart', val: '+2', w: 80, color: C.red },
    { cat: 'Sleep', val: '+3', w: 120, color: C.purple },
    { cat: 'Activity', val: '+1', w: 50, color: C.orange },
  ];

  impacts.forEach((imp, i) => {
    const iy = 710 + i * 30;

    // Category label
    createText(phone, imp.cat, 20, iy, { size: 13, color: C.secondary });

    // Colored bar
    createRect(phone, `Bar ${imp.cat}`, 90, iy + 2, imp.w, 14, {
      color: imp.color,
      radius: 4,
      opacity: 0.7,
    });

    // Value label
    createText(phone, imp.val, 90 + imp.w + 8, iy, {
      size: 13,
      weight: 'semi',
      color: C.green,
    });
  });

  return phone;
}
// ============================================
// PART 5: DETAIL SCREENS
// ============================================
// Depends on Part 1 helpers: createPhoneFrame, addStatusBar, addTabBar,
// addNavBar, addCard, createText, createRect, createCircle, addButton,
// addSectionHeader, addScoreRing, addBadge, addTrendBadge, addSheetHandle,
// addTimeRangeSelector, addInsightCard, addCorrelationCard, addChartPlaceholder,
// addActionCard, addMetricRow, addFilterPills, addGauge, fill,
// Constants: C, PHONE_W, PHONE_H, SCREEN_GAP

function createDetailScreens(page) {
  const screens = [];
  const sx = (i) => i * (PHONE_W + SCREEN_GAP);

  // ------------------------------------------
  // Screen 1: Metric Detail
  // ------------------------------------------
  const s1 = createPhoneFrame(page, 'Detail – Metric', sx(0), 0);
  addStatusBar(s1);
  addNavBar(s1, 'Heart Rate', { rightIcon: 'share' });

  // Time range selector
  addTimeRangeSelector(s1, 1, 108);

  // Chart placeholder — line chart
  addChartPlaceholder(s1, 20, 150, 353, 200);

  // Stats Grid
  const statsCard = addCard(s1, 'Stats Grid', 20, 365, 353, 100);
  // Vertical/horizontal dividers
  createRect(statsCard, 'h-div', 0, 50, 353, 0.5, { color: C.border });
  createRect(statsCard, 'v-div', 176, 0, 0.5, 100, { color: C.border });
  // Top-left: Average
  createText(statsCard, 'Average', 16, 10, { size: 12, color: C.secondary });
  createText(statsCard, '68 bpm', 16, 26, { size: 18, weight: 'bold', color: C.primary });
  // Top-right: Min
  createText(statsCard, 'Min', 193, 10, { size: 12, color: C.secondary });
  createText(statsCard, '52 bpm', 193, 26, { size: 18, weight: 'bold', color: C.primary });
  // Bottom-left: Max
  createText(statsCard, 'Max', 16, 60, { size: 12, color: C.secondary });
  createText(statsCard, '142 bpm', 16, 76, { size: 18, weight: 'bold', color: C.primary });
  // Bottom-right: Baseline
  createText(statsCard, 'Baseline', 193, 60, { size: 12, color: C.secondary });
  createText(statsCard, '65 bpm', 193, 76, { size: 18, weight: 'bold', color: C.primary });

  // Moving Average
  const maCard = addCard(s1, 'Moving Average', 20, 480, 353, 70);
  createText(maCard, '7-day MA: 66 bpm', 16, 12, { size: 14, weight: 'medium', color: C.primary });
  addTrendBadge(maCard, 'down', '-2%', 180, 13);
  createText(maCard, '30-day MA: 68 bpm', 16, 40, { size: 14, weight: 'medium', color: C.primary });

  // Insights
  addSectionHeader(s1, 'Insights', 565);
  addInsightCard(s1, 20, 595, 353, 'Warning', 'Heart', 'Declining trend detected', 'Your resting HR has been declining for 2 weeks \u2014 positive trend');
  addInsightCard(s1, 20, 705, 353, 'Info', 'Heart', 'Above seasonal average', 'Compared to same period last year, HR is 4 bpm lower');

  // No tab bar (pushed view)
  screens.push(s1);

  // ------------------------------------------
  // Screen 2: Metric Log Sheet
  // ------------------------------------------
  const s2 = createPhoneFrame(page, 'Detail – Metric Log', sx(1), 0);
  addSheetHandle(s2);

  // Title and close button
  createText(s2, 'Log Weight', 20, 30, { size: 22, weight: 'bold', color: C.primary });
  createText(s2, '\u2715', PHONE_W - 44, 30, { size: 22, weight: 'medium', color: C.secondary });

  // Last recorded
  createText(s2, 'Last recorded: 76.2 kg', 20, 70, { size: 14, color: C.secondary });

  // Input field
  createRect(s2, 'Input Field', 20, 110, 353, 56, { color: C.card, radius: 12, stroke: C.border });
  createText(s2, 'Enter value', 36, 128, { size: 16, color: C.secondary });
  createText(s2, 'kg', 340, 128, { size: 16, weight: 'medium', color: C.secondary, width: 24, align: 'RIGHT' });

  // Date row
  const dateCard = addCard(s2, 'Date Row', 20, 190, 353, 48, { radius: 12 });
  createText(dateCard, 'Date', 16, 14, { size: 16, color: C.primary });
  createText(dateCard, 'Today', 280, 14, { size: 16, color: C.secondary, width: 50, align: 'RIGHT' });
  createText(dateCard, '\u203A', 337, 12, { size: 18, color: C.secondary });

  // Notes field
  createText(s2, 'Notes (optional)', 20, 260, { size: 14, weight: 'medium', color: C.secondary });
  createRect(s2, 'Notes Field', 20, 284, 353, 80, { color: C.card, radius: 12, stroke: C.border });

  // Save button
  addButton(s2, 'Save', 20, 400, 353, 52, { color: C.accent });

  // Cancel text link
  createText(s2, 'Cancel', 0, 468, { size: 16, color: C.accent, width: PHONE_W, align: 'CENTER' });

  screens.push(s2);

  // ------------------------------------------
  // Screen 3: Category Detail
  // ------------------------------------------
  const s3 = createPhoneFrame(page, 'Detail – Category', sx(2), 0);
  addStatusBar(s3);
  addNavBar(s3, 'Sleep');

  // Category Score Ring centered
  addScoreRing(s3, 127, 110, 120, 72, { label: 'Sleep Score' });

  // "+3 from last week" below ring
  createText(s3, '+3 from last week', 0, 250, { size: 14, weight: 'semi', color: C.green, width: PHONE_W, align: 'CENTER' });

  // Analytics Summary
  const summaryCard = addCard(s3, 'Analytics Summary', 20, 290, 353, 90);
  // 3 stats in a row — each ~117px wide
  createText(summaryCard, 'Avg Duration', 16, 14, { size: 11, color: C.secondary });
  createText(summaryCard, '7h 24m', 16, 34, { size: 18, weight: 'bold', color: C.primary });
  createRect(summaryCard, 'div-1', 126, 12, 0.5, 66, { color: C.border });
  createText(summaryCard, 'Avg Quality', 140, 14, { size: 11, color: C.secondary });
  createText(summaryCard, 'Good', 140, 34, { size: 18, weight: 'bold', color: C.green });
  createRect(summaryCard, 'div-2', 244, 12, 0.5, 66, { color: C.border });
  createText(summaryCard, 'Consistency', 258, 14, { size: 11, color: C.secondary });
  createText(summaryCard, '78%', 258, 34, { size: 18, weight: 'bold', color: C.primary });

  // Time range selector
  addTimeRangeSelector(s3, 1, 400);

  // Historical Highlights
  addSectionHeader(s3, 'Highlights', 445);

  const hl1 = addCard(s3, 'Highlight 1', 20, 478, 353, 60);
  createText(hl1, 'Best week: Feb 12\u201318', 16, 12, { size: 14, weight: 'semi', color: C.primary, width: 240 });
  addBadge(hl1, '8h avg', 280, 12, C.green, C.white);
  createText(hl1, 'Highest average sleep duration this quarter', 16, 36, { size: 12, color: C.secondary, width: 321 });

  const hl2 = addCard(s3, 'Highlight 2', 20, 548, 353, 60);
  createText(hl2, 'Sleep improved 12% since December', 16, 12, { size: 14, weight: 'semi', color: C.primary, width: 280 });
  addTrendBadge(hl2, 'up', '+12%', 300, 13);
  createText(hl2, 'Consistent upward trend over 3 months', 16, 36, { size: 12, color: C.secondary, width: 321 });

  // Metrics in Category
  addSectionHeader(s3, 'Metrics', 625);
  const metricsCard = addCard(s3, 'Metrics List', 20, 658, 353, 180);
  addMetricRow(metricsCard, 'Sleep Duration', '7h 24m', 0, { trend: { dir: 'up', val: '+5%' }, chevron: true });
  addMetricRow(metricsCard, 'Sleep Quality', 'Good', 45, { trend: { dir: 'stable', val: '0%' }, chevron: true });
  addMetricRow(metricsCard, 'Time in Bed', '8h 12m', 90, { trend: { dir: 'stable', val: '0%' }, chevron: true });
  addMetricRow(metricsCard, 'Deep Sleep', '1h 45m', 135, { trend: { dir: 'down', val: '-8%' }, chevron: true, last: true });

  // No tab bar
  screens.push(s3);

  // ------------------------------------------
  // Screen 4: Risk Detail
  // ------------------------------------------
  const s4 = createPhoneFrame(page, 'Detail – Risk', sx(3), 0);
  addStatusBar(s4);
  addNavBar(s4, 'Cardiovascular Risk');

  // Risk Gauge centered
  addGauge(s4, 97, 110, 200, 65, 100);

  // "Moderate Risk" label centered below gauge
  createText(s4, 'Moderate Risk', 0, 235, { size: 18, weight: 'bold', color: C.orange, width: PHONE_W, align: 'CENTER' });

  // Risk Grade card centered
  const gradeCard = addCard(s4, 'Risk Grade', PHONE_W / 2 - 40, 270, 80, 40, { radius: 12 });
  gradeCard.fills = fill(C.orange);
  createText(gradeCard, 'B-', 0, 6, { size: 24, weight: 'bold', color: C.white, width: 80, align: 'CENTER' });

  // Contributing Factors
  addSectionHeader(s4, 'Contributing Factors', 330);

  // Factor 1: Resting HR
  const f1 = addCard(s4, 'Factor – Resting HR', 20, 363, 353, 70);
  createText(f1, 'Resting HR', 16, 10, { size: 14, weight: 'semi', color: C.primary });
  createText(f1, '72 bpm (target: <65)', 16, 30, { size: 12, color: C.secondary });
  addBadge(f1, 'High Impact', 220, 10, C.red, C.white);
  // Progress bar
  createRect(f1, 'bar-bg', 16, 54, 321, 6, { color: C.border, radius: 3 });
  createRect(f1, 'bar-fill', 16, 54, 240, 6, { color: C.red, radius: 3 });

  // Factor 2: HRV
  const f2 = addCard(s4, 'Factor – HRV', 20, 443, 353, 70);
  createText(f2, 'HRV', 16, 10, { size: 14, weight: 'semi', color: C.primary });
  createText(f2, '45ms (target: >55)', 16, 30, { size: 12, color: C.secondary });
  addBadge(f2, 'Medium', 248, 10, C.orange, C.white);
  createRect(f2, 'bar-bg', 16, 54, 321, 6, { color: C.border, radius: 3 });
  createRect(f2, 'bar-fill', 16, 54, 180, 6, { color: C.orange, radius: 3 });

  // Factor 3: Sleep Quality
  const f3 = addCard(s4, 'Factor – Sleep', 20, 523, 353, 70);
  createText(f3, 'Sleep Quality', 16, 10, { size: 14, weight: 'semi', color: C.primary });
  createText(f3, 'Fair (target: Good)', 16, 30, { size: 12, color: C.secondary });
  addBadge(f3, 'Medium', 248, 10, C.orange, C.white);
  createRect(f3, 'bar-bg', 16, 54, 321, 6, { color: C.border, radius: 3 });
  createRect(f3, 'bar-fill', 16, 54, 160, 6, { color: C.orange, radius: 3 });

  // Focus Areas
  addSectionHeader(s4, 'Focus Areas', 610);
  addActionCard(s4, 20, 643, 353, 'Increase aerobic exercise', '3x30min cardio per week to lower resting HR');
  addActionCard(s4, 20, 727, 353, 'Improve sleep consistency', 'Same bedtime \u00B130 min to improve HRV');

  // No tab bar
  screens.push(s4);

  // ------------------------------------------
  // Screen 5: Insights Detail
  // ------------------------------------------
  const s5 = createPhoneFrame(page, 'Detail – Insights', sx(4), 0);
  addStatusBar(s5);
  addNavBar(s5, 'Insights');

  // Segmented control
  const segCard = addCard(s5, 'Segmented Control', 20, 108, 353, 36, { radius: 12 });
  // Left half — active
  createRect(segCard, 'seg-active', 2, 2, 174, 32, { color: C.accent, radius: 10 });
  createText(segCard, 'Action Items', 2, 8, { size: 14, weight: 'semi', color: C.white, width: 174, align: 'CENTER' });
  // Right half — inactive
  createText(segCard, 'All Insights', 177, 8, { size: 14, weight: 'semi', color: C.secondary, width: 174, align: 'CENTER' });

  // Filter pills
  addFilterPills(s5, ['All', 'Sleep', 'Activity', 'Heart', 'Body'], 0, 158);

  // Insight cards
  addInsightCard(s5, 20, 205, 353, 'Critical', 'Heart', 'Elevated resting heart rate', 'Your resting HR has been above baseline for 5 consecutive days');
  addInsightCard(s5, 20, 315, 353, 'Warning', 'Sleep', 'Sleep duration declining', '3 consecutive days below your 7h baseline');
  addInsightCard(s5, 20, 425, 353, 'Warning', 'Activity', 'Step count below target', 'You\'ve missed your 8000 step goal 4 of the last 7 days');
  addInsightCard(s5, 20, 535, 353, 'Info', 'Heart', 'HRV improving', 'Your HRV has increased 8% over the past 2 weeks');
  addInsightCard(s5, 20, 645, 353, 'Info', 'Body', 'Weight trending down', 'Consistent 0.5 lb/week loss over past month');

  // No tab bar
  screens.push(s5);

  // ------------------------------------------
  // Screen 6: Weekly Review
  // ------------------------------------------
  const s6 = createPhoneFrame(page, 'Detail – Weekly Review', sx(5), 0);
  addStatusBar(s6);
  addNavBar(s6, 'Weekly Review');

  // Week header
  createText(s6, 'Feb 24 \u2014 Mar 2', 0, 110, { size: 14, color: C.secondary, width: PHONE_W, align: 'CENTER' });

  // Score Change Hero
  const heroCard = addCard(s6, 'Score Change Hero', 20, 140, 353, 120, { shadow: true });
  // Left score
  createText(heroCard, '74', 50, 20, { size: 36, weight: 'bold', color: C.primary });
  // Arrow
  createText(heroCard, '\u2192', 130, 28, { size: 24, color: C.secondary });
  // Right score
  createText(heroCard, '78', 200, 20, { size: 36, weight: 'bold', color: C.green });
  // Badge centered
  addBadge(heroCard, '+4 points', 137, 68, C.green, C.white);
  // Label below
  createText(heroCard, 'Good progress', 0, 96, { size: 14, color: C.secondary, width: 353, align: 'CENTER' });

  // Wins section
  addSectionHeader(s6, 'Wins', 280);
  const wins = [
    'Hit 10k steps 4 days',
    'Best sleep week in a month',
    'HRV up 8%',
  ];
  wins.forEach((win, i) => {
    const wy = 312 + i * 36;
    // Green checkmark circle
    createCircle(s6, `win-check-${i}`, 28, wy, 16, { color: C.green });
    createText(s6, '\u2713', 32, wy, { size: 10, weight: 'bold', color: C.white });
    createText(s6, win, 54, wy, { size: 15, color: C.primary, width: 300 });
  });

  // Areas to Improve
  addSectionHeader(s6, 'Areas to Improve', 430);
  const goals = [
    'Increase water intake',
    'More consistent bedtime',
  ];
  goals.forEach((goal, i) => {
    const gy = 462 + i * 36;
    // Orange dot indicator
    createCircle(s6, `goal-dot-${i}`, 28, gy + 2, 12, { color: C.orange });
    createText(s6, goal, 54, gy, { size: 15, color: C.primary, width: 300 });
  });

  // Patterns
  addSectionHeader(s6, 'Patterns', 540);
  const patternCard = addCard(s6, 'Pattern Card', 20, 573, 353, 80, { shadow: true });
  createRect(patternCard, 'pattern-icon', 12, 18, 40, 40, { color: C.accent, radius: 12, opacity: 0.15 });
  createRect(patternCard, 'pattern-icon-inner', 22, 28, 20, 20, { color: C.accent, radius: 6 });
  createText(patternCard, 'Weekend activity drop-off detected \u2014 you average 40% fewer steps on weekends', 64, 14, {
    size: 13, color: C.secondary, width: 275, lineHeight: 18,
  });

  // Share button
  addButton(s6, 'Share Weekly Review', 40, 700, PHONE_W - 80, 50, { outlined: true });

  // No tab bar
  screens.push(s6);

  // ------------------------------------------
  // Screen 7: Correlations
  // ------------------------------------------
  const s7 = createPhoneFrame(page, 'Detail – Correlations', sx(6), 0);
  addStatusBar(s7);
  addNavBar(s7, 'Correlations');
  addBadge(s7, 'PRO', PHONE_W - 60, 62, C.orange, C.white);

  // Filter pills
  addFilterPills(s7, ['All', 'Strong', 'Moderate', 'Sleep', 'Exercise', 'Body'], 0, 108);

  // Correlation cards
  addCorrelationCard(s7, 20, 155, 353, 'Sleep Duration', 'HRV', 'Strong', '0.72', 'Longer sleep \u2192 higher next-day HRV');
  addCorrelationCard(s7, 20, 255, 353, 'Steps', 'Resting HR', 'Moderate', '-0.48', 'More steps \u2192 lower resting heart rate');
  addCorrelationCard(s7, 20, 355, 353, 'Exercise Min', 'Sleep Quality', 'Strong', '0.65', 'More exercise \u2192 better sleep quality');
  addCorrelationCard(s7, 20, 455, 353, 'HRV', 'Readiness', 'Strong', '0.81', 'Higher HRV predicts better readiness');
  addCorrelationCard(s7, 20, 555, 353, 'Stress', 'Sleep Duration', 'Moderate', '-0.52', 'Higher stress \u2192 shorter sleep');

  // No tab bar
  screens.push(s7);

  // ------------------------------------------
  // Screen 8: Health State Timeline
  // ------------------------------------------
  const s8 = createPhoneFrame(page, 'Detail – Health States', sx(7), 0);
  addStatusBar(s8);
  addNavBar(s8, 'Health States');

  // Current State Hero
  const stateCard = addCard(s8, 'Current State', 20, 110, 353, 100);
  // Green background tint
  createRect(stateCard, 'state-bg', 0, 0, 353, 100, { color: C.green, radius: 16, opacity: 0.1 });
  // Green circle icon
  createCircle(stateCard, 'state-icon', 16, 32, 36, { color: C.green });
  // State label
  createText(stateCard, 'Thriving', 64, 24, { size: 20, weight: 'bold', color: C.green });
  createText(stateCard, 'You\'ve been in this state for 4 days', 64, 52, { size: 13, color: C.secondary, width: 270 });

  // Calendar Grid
  createText(s8, 'March 2026', 0, 225, { size: 16, weight: 'semi', color: C.primary, width: PHONE_W, align: 'CENTER' });

  // Day labels
  const dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  const calStartX = 20;
  const cellSize = 40;
  const cellGap = 6;
  dayLabels.forEach((d, i) => {
    createText(s8, d, calStartX + i * (cellSize + cellGap) + 12, 252, { size: 12, weight: 'semi', color: C.secondary });
  });

  // Calendar day grid — March 2026 starts on Sunday
  // State color mapping for each day (1-31)
  const stateColors = {
    green: C.green,    // Thriving
    blue: C.accent,    // Recovering
    yellow: C.yellow,  // Stressed
    gray: C.border,    // Baseline
    red: C.red,        // Declining
  };
  // Pattern: mix of states, mostly green
  const dayStates = [
    'green', 'green', 'blue', 'green', 'green', 'yellow', 'green',   // 1-7
    'green', 'blue', 'green', 'green', 'green', 'yellow', 'yellow',  // 8-14
    'blue', 'green', 'green', 'green', 'green', 'gray', 'green',     // 15-21
    'green', 'red', 'blue', 'green', 'green', 'green', 'gray',       // 22-28
    'green', 'green', 'green',                                         // 29-31
  ];

  const calY = 274;
  for (let day = 1; day <= 31; day++) {
    const idx = day - 1;
    const col = idx % 7;
    const row = Math.floor(idx / 7);
    const cx = calStartX + col * (cellSize + cellGap);
    const cy = calY + row * (cellSize + cellGap);
    const stateKey = dayStates[idx];
    const color = stateColors[stateKey];

    if (stateKey === 'gray') {
      // Baseline — border only
      createRect(s8, `day-${day}`, cx, cy, cellSize, cellSize, { color: C.card, radius: 8, stroke: C.border });
    } else {
      createRect(s8, `day-${day}`, cx, cy, cellSize, cellSize, { color: color, radius: 8, opacity: 0.25 });
    }
    createText(s8, String(day), cx, cy + 12, { size: 12, weight: 'medium', color: C.primary, width: cellSize, align: 'CENTER' });
  }

  // Distribution Bar
  const distY = 530;
  const distW = 353;
  const distH = 24;
  const distX = 20;

  // Stacked bar segments: Green 45%, Blue 20%, Yellow 15%, Gray 15%, Red 5%
  const segments = [
    { pct: 0.45, color: C.green, label: 'Thriving', text: '45%' },
    { pct: 0.20, color: C.accent, label: 'Recovering', text: '20%' },
    { pct: 0.15, color: C.yellow, label: 'Stressed', text: '15%' },
    { pct: 0.15, color: C.border, label: 'Baseline', text: '15%' },
    { pct: 0.05, color: C.red, label: 'Declining', text: '5%' },
  ];

  // Background bar
  createRect(s8, 'dist-bg', distX, distY, distW, distH, { color: C.border, radius: 12 });

  // Draw segments left-to-right
  let segX = distX;
  segments.forEach((seg, i) => {
    const segW = Math.round(distW * seg.pct);
    const radius = i === 0 ? 12 : (i === segments.length - 1 ? 12 : 0);
    createRect(s8, `dist-${seg.label}`, segX, distY, segW, distH, { color: seg.color, radius: radius });
    segX += segW;
  });

  // Legend below
  let legendX = 20;
  const legendY = distY + 34;
  segments.forEach((seg) => {
    createCircle(s8, `legend-dot-${seg.label}`, legendX, legendY + 2, 10, { color: seg.color });
    createText(s8, `${seg.label} ${seg.text}`, legendX + 14, legendY, { size: 11, color: C.secondary });
    legendX += seg.label.length * 6 + seg.text.length * 6 + 30;
  });

  // Transition Patterns
  addSectionHeader(s8, 'Patterns', 600);

  const tp1 = addCard(s8, 'Transition 1', 20, 633, 353, 60);
  createText(tp1, 'Stressed \u2192 Thriving usually after 2+ good sleep days', 16, 12, {
    size: 13, color: C.secondary, width: 321, lineHeight: 18,
  });

  const tp2 = addCard(s8, 'Transition 2', 20, 703, 353, 60);
  createText(tp2, 'Weekend recovery pattern detected', 16, 12, {
    size: 13, color: C.secondary, width: 321, lineHeight: 18,
  });

  // No tab bar
  screens.push(s8);

  return screens;
}
// ============================================
// PART 6: SETTINGS, UTILITY & MAIN
// ============================================
// Depends on Part 1 helpers: createPhoneFrame, addStatusBar, addTabBar,
// addNavBar, addCard, createText, createRect, createCircle,
// addButton, addBadge, addSheetHandle, addToggleRow, addSettingsRow,
// addMetricRow, addFilterPills, addSectionHeader, addScoreRing,
// addEmptyState, fill,
// Constants: C, PHONE_W, PHONE_H, SCREEN_GAP
//
// Depends on Parts 2-5: createOnboardingScreens, createHomeScreens,
// createLiveScreens, createExploreScreens, createDetailScreens

function createSettingsScreens(page) {
  const screens = [];
  const gap = PHONE_W + SCREEN_GAP;

  screens.push(buildSettingsMain(page, 0));
  screens.push(buildConnectedDevices(page, gap));
  screens.push(buildDeviceDetail(page, gap * 2));

  return screens;
}

function createUtilityScreens(page) {
  const screens = [];
  const gap = PHONE_W + SCREEN_GAP;

  screens.push(buildFeedbackSheet(page, 0));
  screens.push(buildForceUpdate(page, gap));
  screens.push(buildMaintenance(page, gap * 2));
  screens.push(buildLoading(page, gap * 3));
  screens.push(buildBillingGraceBanner(page, gap * 4));

  return screens;
}

// --------------------------------------------------
// Settings Screen 1: Settings Main
// --------------------------------------------------
function buildSettingsMain(page, x) {
  const phone = createPhoneFrame(page, 'Settings - Main', x, 0);
  addSheetHandle(phone);
  addNavBar(phone, 'Settings', { back: false });

  // Section: CONNECTED DEVICES
  createText(phone, 'CONNECTED DEVICES', 20, 110, { size: 12, weight: 'semi', color: C.secondary });
  const devicesCard = addCard(phone, 'Devices Card', 20, 130, 353, 45);
  addSettingsRow(devicesCard, 'Devices', '2 connected', 0, { chevron: true, last: true });

  // Section: NOTIFICATIONS
  createText(phone, 'NOTIFICATIONS', 20, 190, { size: 12, weight: 'semi', color: C.secondary });
  const notiCard = addCard(phone, 'Notifications Card', 20, 210, 353, 100);
  addToggleRow(notiCard, 'Daily Summary', true, 0);
  createRect(notiCard, 'divider', 16, 50, 321, 0.5, { color: C.border });
  addToggleRow(notiCard, 'Weekly Review', true, 50);

  // Section: ALERTS
  createText(phone, 'ALERTS', 20, 330, { size: 12, weight: 'semi', color: C.secondary });
  const alertsCard = addCard(phone, 'Alerts Card', 20, 350, 353, 100);
  addToggleRow(alertsCard, 'Heart Rate Spike', true, 0);
  createRect(alertsCard, 'divider', 16, 50, 321, 0.5, { color: C.border });
  addToggleRow(alertsCard, 'Heart Rate Drop', false, 50);

  // Section: EXPORT
  createText(phone, 'EXPORT', 20, 470, { size: 12, weight: 'semi', color: C.secondary });
  const exportCard = addCard(phone, 'Export Card', 20, 490, 353, 45);
  addSettingsRow(exportCard, 'Export Health Data', null, 0, { badge: 'PRO', chevron: true, last: true });

  // Section: APPEARANCE
  createText(phone, 'APPEARANCE', 20, 550, { size: 12, weight: 'semi', color: C.secondary });
  const appearanceCard = addCard(phone, 'Appearance Card', 20, 570, 353, 100);
  addSettingsRow(appearanceCard, 'App Icon', null, 0, { chevron: true });
  addSettingsRow(appearanceCard, 'Theme', 'System', 45, { chevron: true, last: true });

  // Section: DATA
  createText(phone, 'DATA', 20, 690, { size: 12, weight: 'semi', color: C.secondary });
  const dataCard = addCard(phone, 'Data Card', 20, 710, 353, 100);
  addSettingsRow(dataCard, 'Clear Cache', null, 0);
  addSettingsRow(dataCard, 'Data Storage', '142 MB', 45, { last: true });

  // Section: ABOUT (near bottom, partially clipped)
  createText(phone, 'ABOUT', 20, 830, { size: 12, weight: 'semi', color: C.secondary });
  const aboutCard = addCard(phone, 'About Card', 20, 850, 353, 45);
  addSettingsRow(aboutCard, 'Version', '1.57', 0, { chevron: false, last: true });

  return phone;
}

// --------------------------------------------------
// Settings Screen 2: Connected Devices
// --------------------------------------------------
function buildConnectedDevices(page, x) {
  const phone = createPhoneFrame(page, 'Settings - Connected Devices', x, 0);
  addStatusBar(phone);
  addNavBar(phone, 'Connected Devices');

  // Scan banner
  const scanBanner = addCard(phone, 'Scan Banner', 20, 110, 353, 36, { radius: 10 });
  createCircle(scanBanner, 'Green Dot', 12, 11, 10, { color: C.green });
  createText(scanBanner, 'Scanning...', 30, 9, { size: 13, weight: 'medium', color: C.primary });
  // Spinner placeholder
  createCircle(scanBanner, 'Spinner', 325, 9, 16, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 2,
  });

  // Section: ACTIVE DEVICES
  createText(phone, 'ACTIVE DEVICES', 20, 165, { size: 12, weight: 'semi', color: C.secondary });

  // Device card 1: Apple Watch
  const device1 = addCard(phone, 'Apple Watch Card', 20, 185, 353, 80, { shadow: true });
  // Device icon placeholder
  createRect(device1, 'Device Icon BG', 12, 18, 44, 44, { color: C.accent, radius: 12, opacity: 0.1 });
  createRect(device1, 'Device Icon', 21, 27, 26, 26, { color: C.accent, radius: 6 });
  createText(device1, 'Apple Watch Series 9', 68, 16, { size: 15, weight: 'semi', color: C.primary });
  addBadge(device1, 'Connected', 68, 40, C.green, C.white);
  createText(device1, '12 metrics', 160, 43, { size: 12, color: C.secondary });
  createText(device1, '\u203A', 329, 28, { size: 18, color: C.secondary });

  // Device card 2: Oura Ring
  const device2 = addCard(phone, 'Oura Ring Card', 20, 275, 353, 80, { shadow: true });
  createRect(device2, 'Device Icon BG', 12, 18, 44, 44, { color: C.accent, radius: 12, opacity: 0.1 });
  createRect(device2, 'Device Icon', 21, 27, 26, 26, { color: C.accent, radius: 6 });
  createText(device2, 'Oura Ring Gen 3', 68, 16, { size: 15, weight: 'semi', color: C.primary });
  addBadge(device2, 'Connected', 68, 40, C.green, C.white);
  createText(device2, '6 metrics', 160, 43, { size: 12, color: C.secondary });
  createText(device2, '\u203A', 329, 28, { size: 18, color: C.secondary });

  // Section: INACTIVE
  createText(phone, 'INACTIVE', 20, 370, { size: 12, weight: 'semi', color: C.secondary });

  const device3 = addCard(phone, 'Withings Card', 20, 390, 353, 80, { shadow: true });
  createRect(device3, 'Device Icon BG', 12, 18, 44, 44, { color: C.secondary, radius: 12, opacity: 0.1 });
  createRect(device3, 'Device Icon', 21, 27, 26, 26, { color: C.secondary, radius: 6 });
  createText(device3, 'Withings Scale', 68, 16, { size: 15, weight: 'semi', color: C.primary });
  addBadge(device3, 'Inactive', 68, 40, C.border, C.secondary);
  createText(device3, 'Last seen: 3 days ago', 68, 58, { size: 12, color: C.secondary });
  createText(device3, '\u203A', 329, 28, { size: 18, color: C.secondary });

  // Section: DISCOVERABLE
  createText(phone, 'DISCOVERABLE', 20, 490, { size: 12, weight: 'semi', color: C.secondary });

  const device4 = addCard(phone, 'Whoop Card', 20, 510, 353, 80, { shadow: true });
  createRect(device4, 'Device Icon BG', 12, 18, 44, 44, { color: C.secondary, radius: 12, opacity: 0.1 });
  createRect(device4, 'Device Icon', 21, 27, 26, 26, { color: C.secondary, radius: 6 });
  createText(device4, 'Whoop 4.0', 68, 24, { size: 15, weight: 'semi', color: C.primary });
  addButton(device4, 'Setup', 271, 24, 70, 30, { color: C.accent, radius: 10, size: 13 });

  return phone;
}

// --------------------------------------------------
// Settings Screen 3: Device Detail
// --------------------------------------------------
function buildDeviceDetail(page, x) {
  const phone = createPhoneFrame(page, 'Settings - Device Detail', x, 0);
  addStatusBar(phone);
  addNavBar(phone, 'Apple Watch Series 9');

  // Device hero
  const heroX = (PHONE_W - 80) / 2;
  createRect(phone, 'Device Hero Icon', heroX, 110, 80, 80, { color: C.accent, radius: 20, opacity: 0.1 });
  createRect(phone, 'Device Hero Inner', heroX + 18, 128, 44, 44, { color: C.accent, radius: 12 });

  // Connected badge centered
  const badgeW = 'Connected'.length * 7 + 16;
  const badgeX = (PHONE_W - badgeW) / 2;
  addBadge(phone, 'Connected', badgeX, 200, C.green, C.white);

  // Last synced
  createText(phone, 'Last synced: Just now', 0, 230, { size: 13, color: C.secondary, width: PHONE_W, align: 'CENTER' });

  // Connected Metrics section
  addSectionHeader(phone, 'Connected Metrics', 270);

  const metricsCard = addCard(phone, 'Metrics List', 20, 300, 353, 540);
  const metrics = [
    ['Heart Rate', '72 bpm'],
    ['HRV', '48 ms'],
    ['Blood Oxygen', '98%'],
    ['Steps', '8,432'],
    ['Sleep', '7h 24m'],
    ['Workouts', '\u2014'],
    ['Resp. Rate', '16 br/min'],
    ['Temperature', '36.6\u00B0C'],
    ['Stand Hours', '9/12'],
    ['Noise', '42 dB'],
    ['ECG', 'Normal'],
    ['Walking Steadiness', 'OK'],
  ];

  metrics.forEach((m, i) => {
    addMetricRow(metricsCard, m[0], m[1], i * 45, {
      chevron: true,
      last: i === metrics.length - 1,
    });
  });

  // Disconnect button
  addButton(phone, 'Disconnect Device', 20, 770, 353, 48, { color: C.red, outlined: true });

  return phone;
}

// --------------------------------------------------
// Utility Screen 1: Feedback Sheet
// --------------------------------------------------
function buildFeedbackSheet(page, x) {
  const phone = createPhoneFrame(page, 'Utility - Feedback Sheet', x, 0);
  addSheetHandle(phone);

  // Title row
  createText(phone, 'Send Feedback', 20, 30, { size: 20, weight: 'bold', color: C.primary });
  createText(phone, '\u2715', PHONE_W - 40, 30, { size: 20, color: C.secondary });

  // Category pills
  addFilterPills(phone, ['Bug', 'Feature', 'General', 'Other'], 0, 75);

  // Textarea
  const textArea = addCard(phone, 'Textarea', 20, 130, 353, 200, { stroke: C.border, strokeWeight: 1 });
  createText(textArea, 'Tell us what\'s on your mind...', 16, 16, { size: 15, color: C.secondary });

  // Submit button
  addButton(phone, 'Submit', 20, 360, 353, 52, { color: C.accent });

  // Footer text
  createText(phone, 'Your feedback helps us improve HealthPulse', 0, 430, {
    size: 12, color: C.secondary, width: PHONE_W, align: 'CENTER',
  });

  return phone;
}

// --------------------------------------------------
// Utility Screen 2: Force Update
// --------------------------------------------------
function buildForceUpdate(page, x) {
  const phone = createPhoneFrame(page, 'Utility - Force Update', x, 0);

  // App icon centered
  const iconX = (PHONE_W - 80) / 2;
  createRect(phone, 'App Icon', iconX, 260, 80, 80, { color: C.accent, radius: 20 });
  // Pulse line inside icon
  createRect(phone, 'Pulse Line', iconX + 15, 293, 50, 6, { color: C.white, radius: 3 });

  // Title
  createText(phone, 'Update Required', 0, 370, {
    size: 26, weight: 'bold', color: C.primary, width: PHONE_W, align: 'CENTER',
  });

  // Body text
  createText(phone, 'A new version of HealthPulse is available. Please update to continue using the app.', 47, 410, {
    size: 16, color: C.secondary, width: 300, align: 'CENTER', lineHeight: 22,
  });

  // Update button
  addButton(phone, 'Update Now', 47, 490, 300, 52, { color: C.accent });

  // Version info
  createText(phone, 'Current: 1.52 \u2192 Required: 1.57', 0, 560, {
    size: 12, color: C.secondary, width: PHONE_W, align: 'CENTER',
  });

  return phone;
}

// --------------------------------------------------
// Utility Screen 3: Maintenance
// --------------------------------------------------
function buildMaintenance(page, x) {
  const phone = createPhoneFrame(page, 'Utility - Maintenance', x, 0);

  // Wrench icon circle
  const circleX = (PHONE_W - 80) / 2;
  createCircle(phone, 'Wrench Circle', circleX, 280, 80, { color: C.secondary, opacity: 0.15 });
  // Wrench shape (simplified as rect)
  createRect(phone, 'Wrench Shape', circleX + 24, 300, 8, 40, { color: C.secondary, radius: 4 });
  createRect(phone, 'Wrench Head', circleX + 20, 296, 16, 16, { color: C.secondary, radius: 3 });

  // Title
  createText(phone, 'We\'ll Be Right Back', 0, 390, {
    size: 24, weight: 'bold', color: C.primary, width: PHONE_W, align: 'CENTER',
  });

  // Body text
  createText(phone, 'HealthPulse is undergoing scheduled maintenance. Your data is safe.', 47, 430, {
    size: 16, color: C.secondary, width: 300, align: 'CENTER', lineHeight: 22,
  });

  // Check Status button (outlined)
  addButton(phone, 'Check Status', 97, 500, 200, 48, { outlined: true });

  return phone;
}

// --------------------------------------------------
// Utility Screen 4: Loading
// --------------------------------------------------
function buildLoading(page, x) {
  const phone = createPhoneFrame(page, 'Utility - Loading', x, 0);

  // Spinner: 3 concentric circles (stroke only, no fill)
  const cx = (PHONE_W - 50) / 2;
  const cy = 340;

  // Outer ring
  createCircle(phone, 'Spinner Outer', cx, cy, 50, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 3,
    arcStart: 0,
    arcEnd: 4.71, // partial arc (~270 degrees)
    innerRadius: 0.88,
  });

  // Middle ring
  const midOffset = (50 - 35) / 2;
  createCircle(phone, 'Spinner Mid', cx + midOffset, cy + midOffset, 35, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 2.5,
    arcStart: 1.57,
    arcEnd: 5.5, // partial arc
    innerRadius: 0.86,
  });

  // Inner ring
  const innerOffset = (50 - 20) / 2;
  createCircle(phone, 'Spinner Inner', cx + innerOffset, cy + innerOffset, 20, {
    fills: [],
    stroke: C.accent,
    strokeWeight: 2,
    arcStart: 3.14,
    arcEnd: 7.33, // partial arc
    innerRadius: 0.8,
  });

  // Loading text
  createText(phone, 'Loading your health data...', 0, 430, {
    size: 16, color: C.secondary, width: PHONE_W, align: 'CENTER',
  });

  return phone;
}

// --------------------------------------------------
// Utility Screen 5: Billing Grace Banner
// --------------------------------------------------
function buildBillingGraceBanner(page, x) {
  const phone = createPhoneFrame(page, 'Utility - Billing Grace Banner', x, 0);
  addStatusBar(phone);

  // Orange warning banner
  createRect(phone, 'Grace Banner BG', 0, 54, PHONE_W, 44, { color: C.orange });
  createText(phone, '\u26A0', 16, 64, { size: 18, color: C.white });
  createText(phone, 'Subscription renewal failed', 40, 68, { size: 13, weight: 'medium', color: C.white });
  createText(phone, 'Fix \u2192', PHONE_W - 56, 68, { size: 13, weight: 'bold', color: C.white });

  // Simplified home content behind (lower opacity)
  const homeContent = createFrame(phone, 'Home Content', 0, 98, PHONE_W, PHONE_H - 98 - 83, {
    fills: [],
    opacity: 0.7,
  });

  // Score ring
  addScoreRing(homeContent, (PHONE_W - 100) / 2, 30, 100, 78, { label: 'Readiness' });

  // Couple of placeholder cards
  const card1 = addCard(homeContent, 'Summary Card 1', 20, 170, 353, 80, { shadow: true });
  createText(card1, 'Today\'s Summary', 16, 12, { size: 14, weight: 'medium', color: C.secondary });
  createText(card1, 'Steps: 6,230 | Sleep: 7h 12m', 16, 36, { size: 15, weight: 'semi', color: C.primary });
  createText(card1, 'Below your weekly average', 16, 58, { size: 12, color: C.secondary });

  const card2 = addCard(homeContent, 'Summary Card 2', 20, 262, 353, 80, { shadow: true });
  createText(card2, 'Heart Rate', 16, 12, { size: 14, weight: 'medium', color: C.secondary });
  createText(card2, '72 bpm resting', 16, 36, { size: 15, weight: 'semi', color: C.primary });
  createText(card2, 'Within normal range', 16, 58, { size: 12, color: C.green });

  addTabBar(phone, 'home');

  return phone;
}


// ============================================
// SECTION LABEL
// ============================================

function addSectionLabel(parent, text, x, y, color) {
  const label = figma.createFrame();
  label.name = text;
  label.x = x;
  label.y = y;
  label.resize(text.length * 13 + 40, 40);
  label.fills = [{ type: 'SOLID', color: color || C.dimBg }];
  label.cornerRadius = 10;
  parent.appendChild(label);

  const t = figma.createText();
  t.characters = text;
  t.fontSize = 18;
  t.fontName = { family: 'Inter', style: 'Bold' };
  t.fills = [{ type: 'SOLID', color: C.white }];
  t.x = 20;
  t.y = 9;
  label.appendChild(t);
  return label;
}

// ============================================
// FONT LOADER
// ============================================

async function tryLoadFont(family, styles) {
  for (var i = 0; i < styles.length; i++) {
    try {
      await figma.loadFontAsync({ family: family, style: styles[i] });
      return styles[i];
    } catch (e) {
      // try next variant
    }
  }
  figma.notify('Warning: could not load ' + family + ' ' + styles[0], { error: true, timeout: 5000 });
  return null;
}

async function loadFonts() {
  await tryLoadFont('Inter', ['Regular']);
  await tryLoadFont('Inter', ['Medium']);
  await tryLoadFont('Inter', ['Semi Bold', 'SemiBold']);
  await tryLoadFont('Inter', ['Bold']);
}

// ============================================
// SINGLE PAGE BUILDER (all 38 screens, 7 rows)
// ============================================

// Yield control back to Figma so the UI stays responsive
function yieldToFigma() {
  return new Promise(function(resolve) { setTimeout(resolve, 50); });
}

async function buildAllOnOnePage(page) {
  page.name = 'HealthPulse — All Screens';
  const rowH = PHONE_H + 120; // space between rows
  let y = 0;

  var rows = [
    { label: 'ONBOARDING (9 screens)',       color: C.purple,    count: 9, create: createOnboardingScreens },
    { label: 'HOME TAB (7 screens)',          color: C.accent,    count: 7, create: createHomeScreens },
    { label: 'LIVE TAB (3 screens)',          color: C.green,     count: 3, create: createLiveScreens },
    { label: 'EXPLORE TAB (3 screens)',       color: C.orange,    count: 3, create: createExploreScreens },
    { label: 'DETAIL SCREENS (8 screens)',    color: C.red,       count: 8, create: createDetailScreens },
    { label: 'SETTINGS (3 screens)',          color: C.secondary, count: 3, create: createSettingsScreens },
    { label: 'UTILITY & SYSTEM (5 screens)',  color: C.purple,    count: 5, create: createUtilityScreens },
  ];

  for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    figma.notify('Building row ' + (i + 1) + '/' + rows.length + ': ' + row.label.split(' (')[0] + '...', { timeout: 3000 });

    addSectionLabel(page, row.label, 0, y, row.color);
    y += 50;
    var wrap = figma.createFrame();
    wrap.name = row.label.split(' (')[0];
    wrap.x = 0; wrap.y = y;
    wrap.resize(row.count * (PHONE_W + SCREEN_GAP), PHONE_H);
    wrap.fills = []; wrap.clipsContent = false;
    page.appendChild(wrap);
    row.create(wrap);
    y += PHONE_H + 120;

    // Yield after each row so Figma can flush the node tree
    await yieldToFigma();
  }
}

// ============================================
// MENU COMMAND HANDLER
// ============================================

figma.on('run', async ({ command }) => {
  try {
    await loadFonts();

    // Always use current page — NEVER create new pages (free plan safe)
    var page = figma.currentPage;

    if (command === 'generate-all' || !command) {
      figma.notify('Generating all HealthPulse screens...');
      // Clear page
      while (page.children.length > 0) { page.children[0].remove(); }
      await buildAllOnOnePage(page);
      figma.viewport.scrollAndZoomIntoView(page.children);
      figma.notify('Done! 38 screens in 7 rows.');

    } else if (command === 'clear-page') {
      var count = page.children.length;
      while (page.children.length > 0) { page.children[0].remove(); }
      figma.notify('Cleared ' + count + ' items.');
    }
  } catch (err) {
    figma.notify('Plugin error: ' + String(err), { error: true, timeout: 10000 });
    console.error('HealthPulse Design System error:', err);
  } finally {
    figma.closePlugin();
  }
});
