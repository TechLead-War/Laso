package com.lasohealth.android.feature.onboarding.v2

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// MARK: - Screen 1: Welcome
@Composable
fun OnbV2Screen1Welcome(onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.weight(1f))
            OnbV2HeartHero()
            Spacer(modifier = Modifier.height(36.dp))
            Text(CopyV2.s1Eyebrow, color = OnbV2.blue, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.6.sp)
            Spacer(modifier = Modifier.height(14.dp))
            Text(CopyV2.s1Title, color = OnbV2.fg, fontSize = 30.sp, fontWeight = FontWeight.Bold, textAlign = TextAlign.Center, lineHeight = 34.sp)
            Spacer(modifier = Modifier.height(16.dp))
            Text(CopyV2.s1Lede, color = OnbV2.fg2, fontSize = 16.sp, textAlign = TextAlign.Center, modifier = Modifier.widthIn(max = 320.dp))
            Spacer(modifier = Modifier.weight(1f))
            OnbV2PrimaryCTA(CopyV2.s1CTA, action = onContinue)
            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

// MARK: - Screen 2: Promise
@Composable
fun OnbV2Screen2Promise(onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 2, total = 16, onBack = onBack)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 24.dp)
            ) {
                Text(CopyV2.s2Title, color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold, lineHeight = 32.sp)
                Spacer(modifier = Modifier.height(12.dp))
                Text(CopyV2.s2Lede, color = OnbV2.fg2, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(28.dp))
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    OnbV2PromiseCard(CopyV2.s2Card1Title, CopyV2.s2Card1Body, OnbV2.blue)
                    OnbV2PromiseCard(CopyV2.s2Card2Title, CopyV2.s2Card2Body, OnbV2.green)
                    OnbV2PromiseCard(CopyV2.s2Card3Title, CopyV2.s2Card3Body, OnbV2.rose)
                }
            }
            Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                OnbV2PrimaryCTA(CopyV2.s2CTA, action = onContinue)
                Text(CopyV2.s2Caption, color = OnbV2.fg4, fontSize = 12.sp, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            }
        }
    }
}

// MARK: - Screen 3: About
@Composable
fun OnbV2Screen3About(profile: OnboardingV2Profile, onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 3, total = 16, onBack = onBack)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 24.dp)
            ) {
                Text(CopyV2.s3Title, color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text(CopyV2.s3Lede, color = OnbV2.fg2, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(28.dp))
                
                // Age selector
                Surface(color = OnbV2.bg2, shape = RoundedCornerShape(18.dp), border = BorderStroke(1.dp, OnbV2.line), modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(18.dp)) {
                        Text(CopyV2.s3AgeLabel, color = OnbV2.fg3, fontSize = 13.sp)
                        Spacer(modifier = Modifier.height(14.dp))
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                            IconButton(onClick = { if (profile.age > 13) profile.age-- }, modifier = Modifier.background(Color.White.copy(0.06f), CircleShape).border(1.dp, OnbV2.line, CircleShape)) {
                                Icon(Icons.Default.Remove, "minus", tint = OnbV2.fg)
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            Row(verticalAlignment = Alignment.Bottom) {
                                Text(profile.age.toString(), color = OnbV2.fg, fontSize = 56.sp, fontWeight = FontWeight.Bold)
                                Spacer(modifier = Modifier.width(6.dp))
                                Text("years", color = OnbV2.fg3, fontSize = 14.sp, modifier = Modifier.padding(bottom = 12.dp))
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            IconButton(onClick = { if (profile.age < 110) profile.age++ }, modifier = Modifier.background(Color.White.copy(0.06f), CircleShape).border(1.dp, OnbV2.line, CircleShape)) {
                                Icon(Icons.Default.Add, "plus", tint = OnbV2.fg)
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(20.dp))
                
                // Sex selector
                Text(CopyV2.s3SexLabel, color = OnbV2.fg3, fontSize = 13.sp)
                Spacer(modifier = Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    OnbV2Sex.values().forEach { s ->
                        val isSelected = profile.sex == s
                        Button(
                            onClick = { profile.sex = s },
                            modifier = Modifier.weight(1f).height(48.dp),
                            shape = RoundedCornerShape(OnbV2.rMd),
                            colors = ButtonDefaults.buttonColors(containerColor = if (isSelected) OnbV2.blue.copy(0.12f) else OnbV2.bg2),
                            border = BorderStroke(1.dp, if (isSelected) OnbV2.blue else OnbV2.line)
                        ) {
                            Text(s.label, color = if (isSelected) OnbV2.blue else OnbV2.fg, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(16.dp))
                Text(CopyV2.s3Microcopy, color = OnbV2.fg4, fontSize = 12.sp, lineHeight = 16.sp)
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA(CopyV2.s3CTA, isEnabled = profile.sex != null, action = onContinue)
            }
        }
    }
}

// MARK: - Screen 4: Goal
@Composable
fun OnbV2Screen4Goal(profile: OnboardingV2Profile, onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 4, total = 16, onBack = onBack)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 24.dp)
            ) {
                Text(CopyV2.s4Title, color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text(CopyV2.s4Lede, color = OnbV2.fg2, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(24.dp))
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OnbV2Goal.values().forEach { g ->
                        val data = CopyV2.goalData(g)
                        OnbV2SelectRow(data.first, data.second, data.third, profile.goals.contains(g)) { profile.toggleGoal(g) }
                    }
                }
            }
            Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(if (profile.goals.isEmpty()) CopyV2.s4ZeroCount else "${profile.goals.size} selected", color = OnbV2.fg4, fontSize = 12.sp, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                OnbV2PrimaryCTA(CopyV2.s4CTA, isEnabled = profile.goals.isNotEmpty(), action = onContinue)
            }
        }
    }
}

// MARK: - Screen 5: Symptoms
@Composable
fun OnbV2Screen5Symptoms(profile: OnboardingV2Profile, onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 5, total = 16, onBack = onBack)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 24.dp)
            ) {
                Text(CopyV2.s5Title, color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text("Pick any that ring true, you can choose more than one. We'll watch for them.", color = OnbV2.fg2, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(24.dp))
                @OptIn(ExperimentalLayoutApi::class)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OnbV2Symptom.values().forEach { s ->
                        OnbV2Chip(s.name.replace("_", " ").lowercase().capitalize(), profile.symptoms.contains(s)) { profile.toggleSymptom(s) }
                    }
                }
            }
            Column(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(if (profile.symptoms.isEmpty()) "Pick any. Or none." else "${profile.symptoms.size} selected", color = OnbV2.fg4, fontSize = 12.sp, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
                OnbV2PrimaryCTA(CopyV2.s5CTA, action = onContinue)
            }
        }
    }
}

// MARK: - Screen 6: Activity
@Composable
fun OnbV2Screen6Activity(profile: OnboardingV2Profile, onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 6, total = 16, onBack = onBack)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 24.dp)
            ) {
                Text(CopyV2.s6Title, color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text(CopyV2.s6Lede, color = OnbV2.fg2, fontSize = 16.sp)
                Spacer(modifier = Modifier.height(24.dp))
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OnbV2Activity.values().forEach { a ->
                        val data = CopyV2.activityData(a)
                        OnbV2SelectRow(data.first, data.second, OnbV2.green, profile.activity == a) { profile.activity = a }
                    }
                }
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA(CopyV2.s6CTA, isEnabled = profile.activity != null, action = onContinue)
            }
        }
    }
}

// MARK: - Screen 7: Wearable
@Composable
fun OnbV2Screen7Wearable(profile: OnboardingV2Profile, onBack: () -> Unit, onContinue: () -> Unit) {
    OnbV2ScreenContainer(ambient = OnbV2Ambient.BLUE) {
        Column(modifier = Modifier.fillMaxSize()) {
            OnbV2TopBar(step = 7, total = 16, onBack = onBack)
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 24.dp, vertical = 24.dp)
            ) {
                Text(CopyV2.s7Title, color = OnbV2.fg, fontSize = 28.sp, fontWeight = FontWeight.Bold)
                Spacer(modifier = Modifier.height(12.dp))
                Text(CopyV2.s7Lede, color = OnbV2.fg2, fontSize = 16.sp, lineHeight = 22.sp)
                Spacer(modifier = Modifier.height(24.dp))
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    OnbV2Wearable.values().forEach { w ->
                        val data = CopyV2.wearableData(w)
                        OnbV2SelectRow(data.first, data.second, OnbV2.blue, profile.wearable == w) { profile.wearable = w }
                    }
                }
            }
            Box(modifier = Modifier.padding(horizontal = 24.dp, vertical = 20.dp)) {
                OnbV2PrimaryCTA(CopyV2.s7CTA, isEnabled = profile.wearable != null, action = onContinue)
            }
        }
    }
}
