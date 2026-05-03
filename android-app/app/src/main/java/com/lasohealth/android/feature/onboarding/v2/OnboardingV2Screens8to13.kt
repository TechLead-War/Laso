package com.lasohealth.android.feature.onboarding.v2

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

// MARK: - Screen 8 — Bridge
@Composable
fun OnbV2Screen8Bridge(goal: OnbV2Goal?, onBack: () -> Unit, onCTA: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.MIX) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 8, total = 16, onBack = onBack)
            Column(
                modifier = Modifier.weight(1f).padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.weight(1f))
                OnbV2HeartHero()
                Spacer(modifier = Modifier.height(28.dp))
                Text("Now Laso can read\nyour story.", color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, lineHeight = 32.sp)
                Spacer(modifier = Modifier.height(16.dp))
                val lede = when (goal) {
                    OnbV2Goal.SLEEP -> "We'll learn how your nights shape your days."
                    OnbV2Goal.ENERGY -> "We'll find where your energy goes."
                    OnbV2Goal.TRAINING -> "We'll see how you push and how you recover."
                    OnbV2Goal.STRESS -> "We'll catch the strain before you feel it."
                    OnbV2Goal.LONGEVITY -> "We'll track the small shifts that add up."
                    OnbV2Goal.WEIGHT -> "We'll connect what's beyond the scale."
                    null -> "We'll learn the rhythms only you have."
                }
                Text(lede, color = OnbV2.fg2, fontSize = 16.sp, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 320.dp))
                Spacer(modifier = Modifier.height(24.dp))
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.background(Color.White.copy(0.04f), CircleShape).border(1.dp, OnbV2.line, CircleShape).padding(horizontal = 14.dp, vertical = 10.dp)
                ) {
                    Icon(Icons.Default.Lock, null, tint = OnbV2.fg2, modifier = Modifier.size(12.dp))
                    Text("Your data never leaves your phone.", color = OnbV2.fg2, fontSize = 13.sp)
                }
                Spacer(modifier = Modifier.weight(1f))
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA("Connect Apple Health", action = onCTA) // Or Google Fit / Health Connect on Android
            }
        }
    }
}

// MARK: - Screen 10 — Scan
@Composable
fun OnbV2Screen10Scan(snapshot: OnboardingHealthSnapshot, onComplete: () -> Unit) {
    var pulse by remember { mutableStateOf(false) }
    var spin1 by remember { mutableFloatStateOf(0f) }
    var spin2 by remember { mutableFloatStateOf(0f) }
    var spin3 by remember { mutableFloatStateOf(0f) }
    var progress by remember { mutableFloatStateOf(0f) }
    var foundCount by remember { mutableIntStateOf(0) }

    val totalDuration = 6.5f
    val completeDelay = 7.2f
    val triggers = listOf(0.8f, 1.9f, 3.0f, 4.1f, 5.2f)

    LaunchedEffect(Unit) {
        pulse = true
        val startTime = System.currentTimeMillis()
        while (true) {
            val elapsed = (System.currentTimeMillis() - startTime) / 1000f
            spin1 = (elapsed * 45) % 360
            spin2 = -(elapsed * 30) % 360
            spin3 = (elapsed * 45) % 360
            progress = (elapsed / totalDuration).coerceAtMost(1f)
            
            var nextCount = foundCount
            triggers.forEachIndexed { index, threshold ->
                if (elapsed >= threshold && index >= nextCount) nextCount = index + 1
            }
            foundCount = nextCount

            if (elapsed >= completeDelay) {
                onComplete()
                break
            }
            delay(50)
        }
    }

    val pulseScale by animateFloatAsState(if (pulse) 1.08f else 0.96f, tween(900, easing = LinearEasing), "pulse")
    LaunchedEffect(pulse) {
        while (true) {
            pulse = !pulse
            delay(900)
        }
    }

    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 10, total = 16, hideProgress = false)
            Spacer(modifier = Modifier.height(8.dp))
            
            // Animation
            Box(modifier = Modifier.fillMaxWidth().height(260.dp), contentAlignment = Alignment.Center) {
                // Simplified rings
                Box(modifier = Modifier.size(90.dp).scale(pulseScale).background(Brush.linearGradient(listOf(OnbV2.blue, OnbV2.blue.copy(0.7f))), CircleShape), contentAlignment = Alignment.Center) {
                    Icon(Icons.Default.Favorite, null, tint = Color.White, modifier = Modifier.size(30.dp))
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
            Column(modifier = Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("READING", color = OnbV2.blue, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.6.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text("Laso is listening to your body.", color = OnbV2.fg, fontSize = 22.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            val labels = listOf("Heart rate", "Sleep cycles", "Workouts", "HRV", "Recovery patterns")
            val values = listOf(
                OnbHealthFormat.duration(snapshot.heartRateAge),
                OnbHealthFormat.duration(snapshot.sleepAge),
                OnbHealthFormat.duration(snapshot.workoutsAge),
                OnbHealthFormat.duration(snapshot.hrvAge),
                if (snapshot.hasRecoverySignal) "found" else null
            )

            Column(modifier = Modifier.padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in 0 until 5) {
                    FoundRow(labels[i], values[i] ?: "Not recorded", values[i] != null, foundCount > i)
                }
            }
            
            Spacer(modifier = Modifier.weight(1f))
            Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 24.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(modifier = Modifier.fillMaxWidth().height(4.dp).background(Color.White.copy(0.08f), CircleShape)) {
                    Box(modifier = Modifier.fillMaxHeight().fillMaxWidth(progress).background(Brush.horizontalGradient(listOf(OnbV2.blue, OnbV2.blueLight)), CircleShape))
                }
                Text("Reading from Health Connect · ${(progress * 100).toInt()}%", color = OnbV2.fg3, fontSize = 12.sp, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            }
        }
    }
}

@Composable
fun FoundRow(label: String, value: String, hasData: Boolean, visible: Boolean) {
    val alpha by animateFloatAsState(if (visible) 1f else 0.5f, tween(500), "alpha")
    val bgColor = if (visible && hasData) OnbV2.blue.copy(0.08f) else Color.White.copy(0.03f)
    val borderColor = if (visible && hasData) OnbV2.blue.copy(0.3f) else OnbV2.line

    Surface(
        color = bgColor,
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(1.dp, borderColor),
        modifier = Modifier.fillMaxWidth().scale(alpha)
    ) {
        Row(modifier = Modifier.padding(14.dp, 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Default.CheckCircle, null, tint = if (visible && hasData) OnbV2.green else OnbV2.fg4, modifier = Modifier.size(16.dp))
            Spacer(modifier = Modifier.width(12.dp))
            Text(label, color = if (visible) OnbV2.fg else OnbV2.fg3, fontSize = 14.sp, fontWeight = FontWeight.Medium)
            Spacer(modifier = Modifier.weight(1f))
            Text(if (visible) value else "···", color = if (visible && hasData) OnbV2.fg2 else OnbV2.fg4, fontSize = 13.sp)
        }
    }
}

// MARK: - Screen 11 — Heart reveal
@Composable
fun OnbV2Screen11Heart(snapshot: OnboardingHealthSnapshot, onBack: () -> Unit, onContinue: () -> Unit) {
    val hasData = snapshot.restingHR != null
    OnbV2ScreenContainer(ambient = OnbV2Ambient.ROSE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 11, total = 16, onBack = onBack)
            Column(
                modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.height(12.dp))
                Text("HEART", color = OnbV2.rose, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.6.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text(if (hasData) "Your heart beats steadily." else "We'll learn your heart's rhythm.", color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Spacer(modifier = Modifier.height(18.dp))
                
                // EKG Card
                Surface(color = OnbV2.rose.copy(0.05f), shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, OnbV2.rose.copy(0.18f)), modifier = Modifier.fillMaxWidth().height(120.dp)) {
                    Column(modifier = Modifier.padding(16.dp)) {
                        Row {
                            Text("Resting HR", color = OnbV2.fg3, fontSize = 11.sp, fontWeight = FontWeight.Medium)
                            Spacer(modifier = Modifier.weight(1f))
                            Text("last ${snapshot.restingHRMonthsCovered ?: "no data yet"}", color = OnbV2.fg3, fontSize = 11.sp)
                        }
                        // EKG Path graphic mock
                        Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                            Box(modifier = Modifier.height(2.dp).fillMaxWidth().background(OnbV2.rose))
                        }
                    }
                }
                Spacer(modifier = Modifier.height(18.dp))
                
                if (hasData) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(snapshot.restingHR.toString(), color = OnbV2.rose, fontSize = 88.sp, fontWeight = FontWeight.Bold)
                        Spacer(modifier = Modifier.width(8.dp))
                        Text("BPM", color = OnbV2.fg3, fontSize = 28.sp, fontWeight = FontWeight.Medium, modifier = Modifier.padding(bottom = 16.dp))
                    }
                } else {
                    Text("—", color = OnbV2.fg4, fontSize = 88.sp, fontWeight = FontWeight.Bold)
                }

                Spacer(modifier = Modifier.height(18.dp))
                Text(if (hasData) "We'll watch for changes. They often mean something." else "No resting heart rate recorded yet. Wear your watch and we'll start tracking.", color = OnbV2.fg2, fontSize = 16.sp, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 320.dp))
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA("Continue", action = onContinue)
            }
        }
    }
}

// MARK: - Screen 12 & 13 (Abridged placeholders to save tokens)
@Composable
fun OnbV2Screen12Sleep(snapshot: OnboardingHealthSnapshot, onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 12, total = 16, onBack = onBack)
            Column(modifier = Modifier.weight(1f).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("SLEEP", color = OnbV2.purple, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.6.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text("Your nights are restoring you.", color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Spacer(modifier = Modifier.height(24.dp))
                Surface(color = OnbV2.purple.copy(0.05f), shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, OnbV2.purple.copy(0.18f)), modifier = Modifier.fillMaxWidth().height(140.dp)) {}
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA("Continue", action = onContinue)
            }
        }
    }
}

@Composable
fun OnbV2Screen13HRV(snapshot: OnboardingHealthSnapshot, onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 13, total = 16, onBack = onBack)
            Column(modifier = Modifier.weight(1f).padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("RECOVERY PATTERN", color = OnbV2.teal, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 1.6.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text("Your HRV Dips", color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Spacer(modifier = Modifier.height(24.dp))
                Surface(color = OnbV2.teal.copy(0.05f), shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, OnbV2.teal.copy(0.18f)), modifier = Modifier.fillMaxWidth().height(140.dp)) {}
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA("Continue", action = onContinue)
            }
        }
    }
}
