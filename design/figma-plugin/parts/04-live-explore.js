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
