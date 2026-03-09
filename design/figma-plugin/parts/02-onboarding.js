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
    innerRadius: ringSize / 2 - 12
  });

  // Foreground ring (60% arc, accent)
  createCircle(phone, "Progress Ring Fill", ringCx, ringCy, ringSize, {
    color: C.accent,
    innerRadius: ringSize / 2 - 12,
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
