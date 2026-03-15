package com.lasohealth.android.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * iOS-matched typography scale.
 *
 * iOS uses SF Pro with specific size/weight pairings and `.rounded` design
 * for hero numerics. We replicate the hierarchy using Material 3 text styles
 * with weights tuned to match iOS's visual density.
 *
 * Key mappings:
 *   iOS .largeTitle (.bold)       → displaySmall (34sp bold)
 *   iOS .title (.bold)           → headlineLarge (28sp bold)
 *   iOS .title2 (.bold)          → headlineMedium (22sp bold)
 *   iOS .title3 (.semibold)      → headlineSmall (20sp semibold)
 *   iOS .headline (.semibold)    → titleLarge (17sp semibold)
 *   iOS .body                    → bodyLarge (17sp)
 *   iOS .callout                 → bodyMedium (16sp)
 *   iOS .subheadline (.regular)  → bodySmall (15sp)
 *   iOS .footnote (.regular)     → labelLarge (13sp)
 *   iOS .caption (.regular)      → labelMedium (12sp)
 *   iOS .caption2 (.regular)     → labelSmall (11sp)
 */
val LasoTypography = Typography(
    // iOS .largeTitle → 34sp bold
    displaySmall = TextStyle(
        fontSize = 34.sp,
        fontWeight = FontWeight.Bold,
        lineHeight = 41.sp,
        letterSpacing = 0.25.sp,
    ),
    // iOS .title → 28sp bold
    headlineLarge = TextStyle(
        fontSize = 28.sp,
        fontWeight = FontWeight.Bold,
        lineHeight = 34.sp,
        letterSpacing = 0.sp,
    ),
    // iOS .title2 → 22sp bold
    headlineMedium = TextStyle(
        fontSize = 22.sp,
        fontWeight = FontWeight.Bold,
        lineHeight = 28.sp,
        letterSpacing = 0.sp,
    ),
    // iOS .title3 → 20sp semibold
    headlineSmall = TextStyle(
        fontSize = 20.sp,
        fontWeight = FontWeight.SemiBold,
        lineHeight = 25.sp,
        letterSpacing = 0.sp,
    ),
    // iOS .headline → 17sp semibold
    titleLarge = TextStyle(
        fontSize = 17.sp,
        fontWeight = FontWeight.SemiBold,
        lineHeight = 22.sp,
        letterSpacing = 0.sp,
    ),
    // iOS section header / bold subheadline → 16sp semibold
    titleMedium = TextStyle(
        fontSize = 16.sp,
        fontWeight = FontWeight.SemiBold,
        lineHeight = 22.sp,
        letterSpacing = 0.15.sp,
    ),
    // iOS smaller bold → 14sp medium
    titleSmall = TextStyle(
        fontSize = 14.sp,
        fontWeight = FontWeight.Medium,
        lineHeight = 20.sp,
        letterSpacing = 0.1.sp,
    ),
    // iOS .body → 17sp regular
    bodyLarge = TextStyle(
        fontSize = 17.sp,
        fontWeight = FontWeight.Normal,
        lineHeight = 22.sp,
        letterSpacing = 0.sp,
    ),
    // iOS .callout → 16sp regular (primary readable size)
    bodyMedium = TextStyle(
        fontSize = 15.sp,
        fontWeight = FontWeight.Normal,
        lineHeight = 20.sp,
        letterSpacing = 0.15.sp,
    ),
    // iOS .subheadline → 15sp regular
    bodySmall = TextStyle(
        fontSize = 13.sp,
        fontWeight = FontWeight.Normal,
        lineHeight = 18.sp,
        letterSpacing = 0.25.sp,
    ),
    // iOS .footnote → 13sp
    labelLarge = TextStyle(
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        lineHeight = 18.sp,
        letterSpacing = 0.1.sp,
    ),
    // iOS .caption → 12sp
    labelMedium = TextStyle(
        fontSize = 12.sp,
        fontWeight = FontWeight.Medium,
        lineHeight = 16.sp,
        letterSpacing = 0.5.sp,
    ),
    // iOS .caption2 → 11sp
    labelSmall = TextStyle(
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        lineHeight = 13.sp,
        letterSpacing = 0.5.sp,
    ),
)
