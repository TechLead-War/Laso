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
