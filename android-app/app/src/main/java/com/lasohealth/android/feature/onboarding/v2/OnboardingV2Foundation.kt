package com.lasohealth.android.feature.onboarding.v2

import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

// MARK: - Profile state
enum class OnbV2Sex(val label: String) { FEMALE("Female"), MALE("Male"), OTHER("Other") }
enum class OnbV2Goal { SLEEP, ENERGY, TRAINING, STRESS, LONGEVITY, WEIGHT }
enum class OnbV2Symptom { TIRED_MORNING, RESTLESS, FOGGY, ANXIOUS, LOW_MOTIVATION, SORE, MOODY, NONE }
enum class OnbV2Activity { LOW, MOD, HIGH, ELITE }
enum class OnbV2Wearable { APPLE, WHOOP, OURA, GARMIN, FITBIT, OTHER, NONE }

class OnboardingV2Profile {
    var age by mutableIntStateOf(26)
    var sex by mutableStateOf<OnbV2Sex?>(null)
    var goals = mutableStateListOf<OnbV2Goal>()
    var symptoms = mutableStateListOf<OnbV2Symptom>()
    var activity by mutableStateOf<OnbV2Activity?>(null)
    var wearable by mutableStateOf<OnbV2Wearable?>(null)

    val primaryGoal: OnbV2Goal? get() = goals.firstOrNull()
    fun toggleGoal(g: OnbV2Goal) { if (goals.contains(g)) goals.remove(g) else goals.add(g) }
    fun toggleSymptom(s: OnbV2Symptom) {
        if (s == OnbV2Symptom.NONE) {
            if (symptoms.contains(OnbV2Symptom.NONE)) symptoms.remove(OnbV2Symptom.NONE)
            else { symptoms.clear(); symptoms.add(OnbV2Symptom.NONE) }
            return
        }
        symptoms.remove(OnbV2Symptom.NONE)
        if (symptoms.contains(s)) symptoms.remove(s) else symptoms.add(s)
    }
}

// MARK: - Tokens
object OnbV2 {
    val bg = Color(0xFF000000)
    val bg1 = Color(0xFF0A0A0C)
    val bg2 = Color(0xFF131317)
    val bg3 = Color(0xFF1C1C22)
    val line = Color.White.copy(alpha = 0.08f)
    val line2 = Color.White.copy(alpha = 0.14f)
    val fg = Color.White
    val fg2 = Color.White.copy(alpha = 0.72f)
    val fg3 = Color.White.copy(alpha = 0.48f)
    val fg4 = Color.White.copy(alpha = 0.28f)
    val blue = Color(0xFF0A84FF)
    val blueGlow = Color(0xFF0A84FF).copy(alpha = 0.55f)
    val blueLight = Color(0xFF5AC8FA)
    val rose = Color(0xFFFF5B6B)
    val green = Color(0xFF34C759)
    val purple = Color(0xFFBF5AF2)
    val amber = Color(0xFFFF9F0A)
    val teal = Color(0xFF5CE0D8)
    val rMd = 16.dp
    val rLg = 22.dp
    val entryEase = CubicBezierEasing(0.22f, 1f, 0.36f, 1f)
}

// MARK: - Screen container
enum class OnbV2Ambient { BLUE, ROSE, MIX, NONE }

@Composable
fun OnbV2ScreenContainer(ambient: OnbV2Ambient, content: @Composable () -> Unit) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val alpha by animateFloatAsState(if (appeared) 1f else 0f, tween(700, easing = OnbV2.entryEase), "alpha")
    val offsetY by animateFloatAsState(if (appeared) 0f else 6f, tween(700, easing = OnbV2.entryEase), "offset")

    Box(modifier = Modifier.fillMaxSize().background(OnbV2.bg)) {
        when (ambient) {
            OnbV2Ambient.BLUE -> AmbientGlow(OnbV2.blue.copy(0.18f), OnbV2.blueLight.copy(0.10f))
            OnbV2Ambient.ROSE -> AmbientGlow(OnbV2.rose.copy(0.16f), OnbV2.purple.copy(0.10f))
            OnbV2Ambient.MIX -> AmbientGlow(OnbV2.blue.copy(0.15f), OnbV2.rose.copy(0.13f))
            OnbV2Ambient.NONE -> {}
        }
        Box(modifier = Modifier.fillMaxSize().offset(y = offsetY.dp).pointerInput(alpha) {}) {
            content()
        }
    }
}

@Composable
private fun AmbientGlow(color1: Color, color2: Color) {
    Box(modifier = Modifier.fillMaxSize().blur(60.dp)) {
        Box(modifier = Modifier.size(280.dp).align(Alignment.TopStart).offset((-80).dp, (-50).dp).background(Brush.radialGradient(listOf(color1, Color.Transparent)), CircleShape))
        Box(modifier = Modifier.size(220.dp).align(Alignment.BottomEnd).offset(50.dp, 50.dp).background(Brush.radialGradient(listOf(color2, Color.Transparent)), CircleShape))
    }
}

// MARK: - TopBar
@Composable
fun OnbV2TopBar(step: Int, total: Int, onBack: (() -> Unit)? = null, hideProgress: Boolean = false) {
    Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        if (onBack != null) {
            Box(modifier = Modifier.size(36.dp).background(Color.White.copy(0.06f), CircleShape).clickable { onBack() }, contentAlignment = Alignment.Center) {
                Icon(Icons.Default.ChevronLeft, "Back", tint = OnbV2.fg2, modifier = Modifier.size(20.dp))
            }
        } else {
            Spacer(modifier = Modifier.size(36.dp))
        }
        Spacer(modifier = Modifier.width(12.dp))
        if (!hideProgress) {
            val progress = if (total > 0) step.toFloat() / total.toFloat() else 0f
            val animatedProgress by animateFloatAsState(progress, tween(600, easing = OnbV2.entryEase), "progress")
            Box(modifier = Modifier.weight(1f).height(4.dp).background(Color.White.copy(0.08f), CircleShape)) {
                Box(modifier = Modifier.fillMaxHeight().fillMaxWidth(animatedProgress).background(Brush.horizontalGradient(listOf(OnbV2.blue, OnbV2.blueLight)), CircleShape))
            }
            Spacer(modifier = Modifier.width(12.dp))
            Text("$step/$total", color = OnbV2.fg3, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
        } else {
            Spacer(modifier = Modifier.weight(1f))
        }
    }
}

// MARK: - CTA
@Composable
fun OnbV2PrimaryCTA(title: String, isEnabled: Boolean = true, action: () -> Unit) {
    var pressed by remember { mutableStateOf(false) }
    val scale by animateFloatAsState(if (pressed) 0.985f else 1f, label = "scale")
    Box(
        modifier = Modifier.fillMaxWidth().height(56.dp).scale(scale).background(if (isEnabled) OnbV2.blue else Color.White.copy(0.08f), RoundedCornerShape(OnbV2.rMd)).pointerInput(isEnabled) {
            if (isEnabled) {
                detectTapGestures(onPress = { pressed = true; tryAwaitRelease(); pressed = false; action() })
            }
        },
        contentAlignment = Alignment.Center
    ) {
        Text(title, color = if (isEnabled) Color.White else OnbV2.fg3, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun OnbV2GhostCTA(title: String, action: () -> Unit) {
    TextButton(onClick = action, modifier = Modifier.fillMaxWidth().height(44.dp)) {
        Text(title, color = OnbV2.fg2, fontSize = 15.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun OnbV2SelectRow(title: String, subtitle: String, accent: Color, isSelected: Boolean, action: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable { action() },
        color = if (isSelected) accent.copy(0.10f) else OnbV2.bg2,
        shape = RoundedCornerShape(OnbV2.rMd),
        border = BorderStroke(1.dp, if (isSelected) accent else OnbV2.line)
    ) {
        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(modifier = Modifier.size(42.dp).background(accent.copy(if(isSelected) 0.22f else 0.14f), RoundedCornerShape(12.dp)))
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, color = OnbV2.fg, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                Text(subtitle, color = OnbV2.fg3, fontSize = 13.sp)
            }
            Box(modifier = Modifier.size(22.dp), contentAlignment = Alignment.Center) {
                Surface(modifier = Modifier.fillMaxSize(), shape = CircleShape, color = Color.Transparent, border = BorderStroke(1.5f, if (isSelected) accent else OnbV2.fg4)) {}
                if (isSelected) Icon(Icons.Default.Check, null, tint = accent, modifier = Modifier.size(16.dp))
            }
        }
    }
}

@Composable
fun OnbV2Chip(label: String, isSelected: Boolean, action: () -> Unit) {
    Surface(
        modifier = Modifier.clickable { action() },
        color = if (isSelected) OnbV2.blue.copy(0.12f) else OnbV2.bg2,
        shape = CircleShape,
        border = BorderStroke(1.dp, if (isSelected) OnbV2.blue else OnbV2.line)
    ) {
        Text(label, color = if (isSelected) OnbV2.blue else OnbV2.fg, fontSize = 14.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp))
    }
}

@Composable
fun OnbV2PromiseCard(title: String, bodyText: String, accent: Color) {
    Surface(color = OnbV2.bg2, shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, OnbV2.line), modifier = Modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.Top) {
            Box(modifier = Modifier.size(40.dp).background(accent.copy(0.14f), RoundedCornerShape(12.dp)))
            Spacer(modifier = Modifier.width(14.dp))
            Column {
                Text(title, color = OnbV2.fg, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                Spacer(modifier = Modifier.height(4.dp))
                Text(bodyText, color = OnbV2.fg3, fontSize = 13.5.sp, lineHeight = 20.sp)
            }
        }
    }
}

@Composable
fun OnbV2HeartHero() {
    Box(modifier = Modifier.size(220.dp), contentAlignment = Alignment.Center) {
        Box(modifier = Modifier.size(80.dp).background(Brush.linearGradient(listOf(OnbV2.blue, OnbV2.blue.copy(0.7f))), CircleShape))
    }
}

object CopyV2 {
    val s1Eyebrow = "LASO"
    val s1Title   = "You deserve\nto feel understood."
    val s1Lede    = "Not another health app shouting numbers at you. Laso listens to what your body has been quietly telling you for years, and helps you finally hear it."
    val s1CTA     = "Begin"
    val s2Title = "A few things,\nbefore we start."
    val s2Lede  = "What we promise you, in plain words."
    val s2Card1Title = "No noise. No panic."
    val s2Card1Body  = "We won't bury you in numbers. Just what matters, in words you'll actually use."
    val s2Card2Title = "Yours, and only yours."
    val s2Card2Body  = "Your health data stays on your phone. We never sell it. We never share it."
    val s2Card3Title = "You're not alone in this."
    val s2Card3Body  = "Whether you're tired, off, or hopeful, we meet you where you are."
    val s2CTA     = "I'm ready"
    val s2Caption = "Takes about 2 minutes"
    val s3Title = "First, the basics."
    val s3Lede  = "Heart, sleep, and recovery shift at every life stage. Yours are yours alone."
    val s3AgeLabel = "How old are you?"
    val s3SexLabel = "Sex assigned at birth"
    val s3Microcopy = "We use this only to set healthy ranges for things like resting heart rate. Never shared."
    val s3CTA = "Continue"
    val s4Title = "What brought you here?"
    val s4Lede  = "Pick anything that fits today. You can change it later."
    val s4CTA   = "Continue"
    val s4ZeroCount = "Pick one or a few"
    val s5Title = "What's been bugging you?"
    val s5CTA   = "Continue"
    val s6Title = "How active are you, usually?"
    val s6Lede  = "Helps us read your recovery in context."
    val s6CTA   = "Continue"
    val s7Title = "Do you wear anything?"
    val s7Lede  = "We don't connect to your watch directly. We read whatever it shares with Apple Health. Most modern wearables do."
    val s7CTA   = "Continue"
    
    fun goalData(g: OnbV2Goal) = when(g) {
        OnbV2Goal.SLEEP -> Triple("Sleep better", "Wake up rested. Stop tossing.", OnbV2.purple)
        OnbV2Goal.ENERGY -> Triple("More steady energy", "Even out the highs and crashes.", OnbV2.amber)
        OnbV2Goal.TRAINING -> Triple("Train smarter", "Push hard, recover faster.", OnbV2.green)
        OnbV2Goal.STRESS -> Triple("Manage stress", "Notice it before it builds.", OnbV2.teal)
        OnbV2Goal.LONGEVITY -> Triple("Stay healthy long-term", "Spot small changes before they grow.", OnbV2.rose)
        OnbV2Goal.WEIGHT -> Triple("Move toward a weight goal", "Without obsessing over it.", OnbV2.blue)
    }
    fun activityData(a: OnbV2Activity) = when(a) {
        OnbV2Activity.LOW -> Pair("Mostly desk-bound", "A walk here and there.")
        OnbV2Activity.MOD -> Pair("On my feet", "Walks, light workouts most weeks.")
        OnbV2Activity.HIGH -> Pair("Train regularly", "3 to 5 sessions a week.")
        OnbV2Activity.ELITE -> Pair("Athlete", "Daily, structured training.")
    }
    fun wearableData(w: OnbV2Wearable) = when(w) {
        OnbV2Wearable.APPLE -> Pair("Apple Watch", "Best fit. Deepest signal.")
        OnbV2Wearable.WHOOP -> Pair("Whoop", "Strain, sleep, recovery.")
        OnbV2Wearable.OURA -> Pair("Oura Ring", "Sleep, HRV, body temp.")
        OnbV2Wearable.GARMIN -> Pair("Garmin / Polar", "Training-focused devices.")
        OnbV2Wearable.FITBIT -> Pair("Fitbit", "Steps, sleep, heart rate.")
        OnbV2Wearable.OTHER -> Pair("Something else", "If it syncs to Apple Health, we'll read it.")
        OnbV2Wearable.NONE -> Pair("Just my iPhone for now", "That's plenty to start.")
    }
}

data class OnboardingHealthSnapshot(
    val heartRateAge: Double? = null,
    val sleepAge: Double? = null,
    val workoutsAge: Double? = null,
    val hrvAge: Double? = null,
    val hasRecoverySignal: Boolean = false,
    val restingHR: Int? = null,
    val restingHRMonthsCovered: Int? = null,
    val sleepAvgHours: Int? = null,
    val sleepAvgMins: Int? = null,
    val sleepLast7Nights: List<Double> = emptyList(),
    val sleepMonthsCovered: Int? = null,
    val hrvWorstWeekday: Int? = null,
    val hrvWeekdayMeans: List<Double?> = List(7) { null },
    val hrvWeeklyAvgMs: Double? = null,
    val hrvWeeksCovered: Int? = null
)

object OnbHealthFormat {
    fun duration(age: Double?): String? {
        if (age == null) return null
        return "${age.toInt()}d" // simplified for UI mock
    }
    fun weekdayName(day: Int?): String? {
        return when (day) {
            1 -> "Sunday"
            2 -> "Monday"
            3 -> "Tuesday"
            4 -> "Wednesday"
            5 -> "Thursday"
            6 -> "Friday"
            7 -> "Saturday"
            else -> null
        }
    }
}
