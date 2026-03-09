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

async function loadFonts() {
  await figma.loadFontAsync({ family: 'Inter', style: 'Regular' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Medium' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Semi Bold' });
  await figma.loadFontAsync({ family: 'Inter', style: 'Bold' });
}

// ============================================
// SINGLE PAGE BUILDER (all 38 screens, 7 rows)
// ============================================

function buildAllOnOnePage(page) {
  page.name = 'HealthPulse — All Screens';
  const rowH = PHONE_H + 120; // space between rows
  let y = 0;

  // ROW 1: Onboarding (9 screens)
  addSectionLabel(page, 'ONBOARDING (9 screens)', 0, y, C.purple);
  y += 50;
  var wrap1 = figma.createFrame();
  wrap1.name = 'Onboarding';
  wrap1.x = 0; wrap1.y = y;
  wrap1.resize(9 * (PHONE_W + SCREEN_GAP), PHONE_H);
  wrap1.fills = []; wrap1.clipsContent = false;
  page.appendChild(wrap1);
  createOnboardingScreens(wrap1);
  y += PHONE_H + 120;

  // ROW 2: Home Tab (7 screens)
  addSectionLabel(page, 'HOME TAB (7 screens)', 0, y, C.accent);
  y += 50;
  var wrap2 = figma.createFrame();
  wrap2.name = 'Home Tab';
  wrap2.x = 0; wrap2.y = y;
  wrap2.resize(7 * (PHONE_W + SCREEN_GAP), PHONE_H);
  wrap2.fills = []; wrap2.clipsContent = false;
  page.appendChild(wrap2);
  createHomeScreens(wrap2);
  y += PHONE_H + 120;

  // ROW 3: Live Tab (3 screens)
  addSectionLabel(page, 'LIVE TAB (3 screens)', 0, y, C.green);
  y += 50;
  var wrap3 = figma.createFrame();
  wrap3.name = 'Live Tab';
  wrap3.x = 0; wrap3.y = y;
  wrap3.resize(3 * (PHONE_W + SCREEN_GAP), PHONE_H);
  wrap3.fills = []; wrap3.clipsContent = false;
  page.appendChild(wrap3);
  createLiveScreens(wrap3);
  y += PHONE_H + 120;

  // ROW 4: Explore Tab (3 screens)
  addSectionLabel(page, 'EXPLORE TAB (3 screens)', 0, y, C.orange);
  y += 50;
  var wrap4 = figma.createFrame();
  wrap4.name = 'Explore Tab';
  wrap4.x = 0; wrap4.y = y;
  wrap4.resize(3 * (PHONE_W + SCREEN_GAP), PHONE_H);
  wrap4.fills = []; wrap4.clipsContent = false;
  page.appendChild(wrap4);
  createExploreScreens(wrap4);
  y += PHONE_H + 120;

  // ROW 5: Detail Screens (8 screens)
  addSectionLabel(page, 'DETAIL SCREENS (8 screens)', 0, y, C.red);
  y += 50;
  var wrap5 = figma.createFrame();
  wrap5.name = 'Detail Screens';
  wrap5.x = 0; wrap5.y = y;
  wrap5.resize(8 * (PHONE_W + SCREEN_GAP), PHONE_H);
  wrap5.fills = []; wrap5.clipsContent = false;
  page.appendChild(wrap5);
  createDetailScreens(wrap5);
  y += PHONE_H + 120;

  // ROW 6: Settings (3 screens)
  addSectionLabel(page, 'SETTINGS (3 screens)', 0, y, C.secondary);
  y += 50;
  var wrap6 = figma.createFrame();
  wrap6.name = 'Settings';
  wrap6.x = 0; wrap6.y = y;
  wrap6.resize(3 * (PHONE_W + SCREEN_GAP), PHONE_H);
  wrap6.fills = []; wrap6.clipsContent = false;
  page.appendChild(wrap6);
  createSettingsScreens(wrap6);
  y += PHONE_H + 120;

  // ROW 7: Utility (5 screens)
  addSectionLabel(page, 'UTILITY & SYSTEM (5 screens)', 0, y, C.purple);
  y += 50;
  var wrap7 = figma.createFrame();
  wrap7.name = 'Utility & System';
  wrap7.x = 0; wrap7.y = y;
  wrap7.resize(5 * (PHONE_W + SCREEN_GAP), PHONE_H);
  wrap7.fills = []; wrap7.clipsContent = false;
  page.appendChild(wrap7);
  createUtilityScreens(wrap7);
}

// ============================================
// MENU COMMAND HANDLER
// ============================================

figma.on('run', async ({ command }) => {
  await loadFonts();

  // Always use current page — NEVER create new pages (free plan safe)
  var page = figma.currentPage;

  if (command === 'generate-all' || !command) {
    figma.notify('Generating all HealthPulse screens...');
    // Clear page
    while (page.children.length > 0) { page.children[0].remove(); }
    buildAllOnOnePage(page);
    figma.viewport.scrollAndZoomIntoView(page.children);
    figma.notify('Done! 38 screens in 7 rows.');

  } else if (command === 'clear-page') {
    var count = page.children.length;
    while (page.children.length > 0) { page.children[0].remove(); }
    figma.notify('Cleared ' + count + ' items.');
  }

  figma.closePlugin();
});
