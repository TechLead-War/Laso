package com.lasohealth.android.feature.onboarding.v2

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apple
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.MonitorHeart
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material.icons.filled.TrendingUp
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// MARK: - Screen 14: Preview
@Composable
fun OnbV2Screen14Preview(onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 14, total = 16, onBack = onBack)
            Column(
                modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp)
            ) {
                Text("YOUR TIMELINE", color = OnbV2.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.6.sp)
                Spacer(modifier = Modifier.height(12.dp))
                Text("Here's what happens next.", color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text("It takes a little time to learn your unique baseline.", color = OnbV2.fg2, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(22.dp))
                
                // Timeline
                Box(modifier = Modifier.fillMaxWidth()) {
                    // Vertical line
                    Box(modifier = Modifier.padding(start = 7.dp).width(2.dp).fillMaxHeight().background(Brush.verticalGradient(listOf(OnbV2.blue, OnbV2.blue.copy(0.1f)))))
                    
                    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        TimelineItem(0, "DAY 1", "Initial sync", "We establish your raw data.")
                        TimelineItem(1, "DAY 3", "First patterns", "We start seeing how you recover.")
                        TimelineItem(2, "DAY 7", "Baseline set", "Your personal ranges are established.")
                        TimelineItem(3, "DAY 14", "Deep insights", "Laso begins predicting your needs.")
                    }
                }
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA("Continue", action = onContinue)
            }
        }
    }
}

@Composable
private fun TimelineItem(idx: Int, day: String, title: String, body: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        Box(modifier = Modifier.size(16.dp), contentAlignment = Alignment.Center) {
            if (idx == 0) Box(modifier = Modifier.size(24.dp).border(4.dp, OnbV2.blue.copy(0.2f), CircleShape))
            Box(modifier = Modifier.size(16.dp).background(OnbV2.bg, CircleShape).border(2.dp, OnbV2.blue, CircleShape))
        }
        Column(modifier = Modifier.padding(top = (-2).dp)) {
            Text(day, color = OnbV2.blue, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.7.sp)
            Text(title, color = OnbV2.fg, fontSize = 16.sp, fontWeight = FontWeight.Bold)
            Text(body, color = OnbV2.fg3, fontSize = 13.5.sp)
        }
    }
}

// MARK: - Screen 15: Sign in
@Composable
fun OnbV2Screen15SignIn(onBack: () -> Unit, onSignedIn: () -> Unit) {
    var isAuthing by remember { mutableStateOf(false) }
    
    OnbV2ScreenContainer(ambient = OnbV2Ambient.MIX) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 15, total = 16, onBack = onBack)
            Column(
                modifier = Modifier.weight(1f).padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Spacer(modifier = Modifier.weight(1f))
                OnbV2HeartHero()
                Spacer(modifier = Modifier.height(28.dp))
                Text("Save your profile.", color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center)
                Spacer(modifier = Modifier.height(14.dp))
                Text("Create an account to securely sync your data across devices.", color = OnbV2.fg2, fontSize = 16.sp, textAlign = TextAlign.Center)
                Spacer(modifier = Modifier.weight(1f))
            }
            Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(
                    onClick = {
                        isAuthing = true
                        // Mock sign in
                        onSignedIn()
                    },
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Icon(Icons.Default.Apple, null, tint = Color.Black)
                        Text("Sign in with Apple", color = Color.Black, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                    }
                }
                Text("We never sell or share your data.", color = OnbV2.fg4, fontSize = 11.5.sp, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
        }
    }
}

// MARK: - Screen 16: Paywall
@Composable
fun OnbV2Screen16Paywall(onBack: () -> Unit, onPurchased: () -> Unit) {
    var selectedIsAnnual by remember { mutableStateOf(true) }
    val uriHandler = LocalUriHandler.current

    OnbV2ScreenContainer(ambient = OnbV2Ambient.MIX) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 16, total = 16, onBack = onBack)
            Column(
                modifier = Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(24.dp)
            ) {
                Text("UNLOCK LASO", color = OnbV2.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.6.sp)
                Spacer(modifier = Modifier.height(8.dp))
                Text("Your personal health intelligence.", color = OnbV2.fg, fontSize = 26.sp, fontWeight = FontWeight.Bold, lineHeight = 30.sp)
                Spacer(modifier = Modifier.height(18.dp))
                
                // Watchlist rows
                Surface(color = OnbV2.bg2, shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, OnbV2.line), modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(6.dp)) {
                        WatchRow(Icons.Default.MonitorHeart, OnbV2.blue, "Live vitals & 58+ metrics", "Read directly from your device.")
                        Divider(color = OnbV2.line)
                        WatchRow(Icons.Default.Psychology, OnbV2.rose, "Root cause analysis", "Connect symptoms to data.")
                        Divider(color = OnbV2.line)
                        WatchRow(Icons.Default.TrendingUp, OnbV2.amber, "Trends & correlations", "Spot the patterns that matter.")
                        Divider(color = OnbV2.line)
                        WatchRow(Icons.Default.Shield, OnbV2.green, "On-device privacy", "Your data stays with you.")
                    }
                }
                
                Spacer(modifier = Modifier.height(18.dp))
                
                // Plans
                OnbV2PlanCard("Yearly", "$49.99/yr", "That's about $4.16 per month", "Save 40%", selectedIsAnnual) { selectedIsAnnual = true }
                Spacer(modifier = Modifier.height(10.dp))
                OnbV2PlanCard("Monthly", "$6.99/mo", "Cancel anytime", null, !selectedIsAnnual) { selectedIsAnnual = false }
            }
            
            Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OnbV2PrimaryCTA("Start 7 day free trial") { onPurchased() }
                Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                    TextButton(onClick = { /* Restore */ }) { Text("Restore purchases", color = OnbV2.fg4, fontSize = 12.sp) }
                }
                Row(horizontalArrangement = Arrangement.Center, modifier = Modifier.fillMaxWidth()) {
                    TextButton(onClick = { uriHandler.openUri("https://laso.ai/terms") }) { Text("Terms", color = OnbV2.fg4, fontSize = 11.5.sp) }
                    TextButton(onClick = { uriHandler.openUri("https://laso.ai/privacy") }) { Text("Privacy", color = OnbV2.fg4, fontSize = 11.5.sp) }
                }
            }
        }
    }
}

@Composable
private fun WatchRow(icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, label: String, sub: String) {
    Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(modifier = Modifier.size(32.dp).background(color.copy(0.18f), RoundedCornerShape(9.dp)), contentAlignment = Alignment.Center) {
            Icon(icon, null, tint = color, modifier = Modifier.size(15.dp))
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(label, color = OnbV2.fg, fontSize = 14.5.sp, fontWeight = FontWeight.Medium)
            Text(sub, color = OnbV2.fg4, fontSize = 12.sp)
        }
        Icon(Icons.Default.CheckCircle, null, tint = OnbV2.green, modifier = Modifier.size(14.dp))
    }
}

@Composable
private fun OnbV2PlanCard(title: String, priceText: String, sublabel: String, badge: String?, isSelected: Boolean, onClick: () -> Unit) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        color = if (isSelected) OnbV2.blue.copy(0.10f) else OnbV2.bg2,
        shape = RoundedCornerShape(OnbV2.rMd),
        border = BorderStroke(1.5f, if (isSelected) OnbV2.blue else OnbV2.line)
    ) {
        Row(modifier = Modifier.padding(16.dp, 14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(modifier = Modifier.size(22.dp).border(1.5f, if (isSelected) OnbV2.blue else OnbV2.fg4, CircleShape), contentAlignment = Alignment.Center) {
                if (isSelected) Box(modifier = Modifier.size(12.dp).background(OnbV2.blue, CircleShape))
            }
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(title, color = OnbV2.fg, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                    if (badge != null) {
                        Surface(color = OnbV2.green.copy(0.18f), shape = CircleShape) {
                            Text(badge, color = OnbV2.green, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.4.sp, modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp))
                        }
                    }
                }
                Spacer(modifier = Modifier.height(3.dp))
                Text(sublabel, color = OnbV2.fg3, fontSize = 12.5.sp)
            }
            Text(priceText, color = OnbV2.fg, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
        }
    }
}
