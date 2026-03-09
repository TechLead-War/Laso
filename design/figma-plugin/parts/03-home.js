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
