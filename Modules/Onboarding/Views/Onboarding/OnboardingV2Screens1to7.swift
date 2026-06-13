import SwiftUI

// MARK: - Screen 1: Welcome

struct OnbV2Screen1Welcome: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    // Hero settles in from a hair larger so the whole screen reads as one
    // breath, then the copy cascades beneath it.
    @State private var heroSettled = false
    @State private var beginTapped = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                OnbV2HeartHero(size: 220)
                    .scaleEffect(heroSettled || reduceMotion ? 1 : 1.06)
                    .opacity(heroSettled ? 1 : 0)
                    .animation(reduceMotion ? .easeOut(duration: 0.15)
                                            : OnbV2.entryEase, value: heroSettled)

                Spacer().frame(height: 36)

                Text(Copy.OnboardingV2.s1Eyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(OnbV2.blue)
                    .onbV2StaggerIn(index: 1, appeared: appeared, tight: true)

                Spacer().frame(height: 14)

                Text(Copy.OnboardingV2.s1Title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .onbV2StaggerIn(index: 2, appeared: appeared)

                Spacer().frame(height: 16)

                Text(Copy.OnboardingV2.s1Lede)
                    .font(.system(size: 16))
                    .foregroundStyle(OnbV2.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                    .onbV2StaggerIn(index: 3, appeared: appeared)

                Spacer(minLength: 0)

                OnbV2PrimaryCTA(Copy.OnboardingV2.s1CTA) {
                    beginTapped = true
                    onContinue()
                }
                .onbV2StaggerIn(index: 4, appeared: appeared)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, OnbV2.bodyPadH)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: beginTapped)
        .task {
            heroSettled = true
            appeared = true
        }
    }
}

// MARK: - Screen 2: Promise

struct OnbV2Screen2Promise: View {
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var ctaTapped = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 2, total: OnbV2Flow.total, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s2Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .lineSpacing(4)
                            .onbV2StaggerIn(index: 0, appeared: appeared)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s2Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .onbV2StaggerIn(index: 1, appeared: appeared)

                        Spacer().frame(height: 28)

                        // Empowerment leads, connection next, privacy last as a
                        // footnote (onboarding framing: what the user gains is
                        // the headline, privacy reassures but never leads).
                        VStack(spacing: 14) {
                            OnbV2PromiseCard(
                                icon: "sparkles",
                                title: Copy.OnboardingV2.s2Card1Title,
                                bodyText: Copy.OnboardingV2.s2Card1Body,
                                accent: OnbV2.blue
                            )
                            .onbV2StaggerIn(index: 2, appeared: appeared)
                            OnbV2PromiseCard(
                                icon: "heart.fill",
                                title: Copy.OnboardingV2.s2Card3Title,
                                bodyText: Copy.OnboardingV2.s2Card3Body,
                                accent: OnbV2.rose
                            )
                            .onbV2StaggerIn(index: 3, appeared: appeared)
                            OnbV2PromiseCard(
                                icon: "lock.fill",
                                title: Copy.OnboardingV2.s2Card2Title,
                                bodyText: Copy.OnboardingV2.s2Card2Body,
                                accent: OnbV2.green
                            )
                            .onbV2StaggerIn(index: 4, appeared: appeared)
                        }

                        // Absorbs slack on tall devices so the cards sit just
                        // under the lede instead of floating in a centred void.
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .frame(maxWidth: .infinity, minHeight: 0, alignment: .top)
                }

                VStack(spacing: 6) {
                    OnbV2PrimaryCTA(Copy.OnboardingV2.s2CTA) {
                        ctaTapped = true
                        onContinue()
                    }
                    Text(Copy.OnboardingV2.s2Caption)
                        .font(.system(size: 12))
                        .foregroundStyle(OnbV2.fg4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
                .onbV2StaggerIn(index: 5, appeared: appeared)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ctaTapped)
        .task { appeared = true }
    }
}

// MARK: - Screen 3: About

struct OnbV2Screen3About: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var ctaTapped = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 3, total: OnbV2Flow.total, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s3Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .onbV2StaggerIn(index: 0, appeared: appeared)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s3Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .onbV2StaggerIn(index: 1, appeared: appeared)

                        Spacer().frame(height: 28)

                        // Age stepper section
                        VStack(alignment: .leading, spacing: 14) {
                            Text(Copy.OnboardingV2.s3AgeLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(OnbV2.fg3)

                            HStack(spacing: 0) {
                                Button {
                                    if profile.age > 13 { bumpAge(-1) }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(OnbV2.fg)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.white.opacity(0.06)))
                                        .overlay(Circle().stroke(OnbV2.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(profile.age <= 13)
                                .opacity(profile.age <= 13 ? 0.4 : 1)

                                Spacer(minLength: 0)

                                HStack(alignment: .lastTextBaseline, spacing: 6) {
                                    Text(Copy.Onboarding.xText(profile.age))
                                        .font(.system(size: 56, weight: .bold).monospacedDigit())
                                        .foregroundStyle(OnbV2.fg)
                                        // Rolls each digit on +/- taps; the age is
                                        // discrete so this beats a CountUp ramp.
                                        .contentTransition(.numericText(value: Double(profile.age)))
                                    Text(Copy.Onboarding.years)
                                        .font(.system(size: 14))
                                        .foregroundStyle(OnbV2.fg3)
                                }

                                Spacer(minLength: 0)

                                Button {
                                    if profile.age < 110 { bumpAge(1) }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(OnbV2.fg)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Color.white.opacity(0.06)))
                                        .overlay(Circle().stroke(OnbV2.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .disabled(profile.age >= 110)
                                .opacity(profile.age >= 110 ? 0.4 : 1)
                            }
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(OnbV2.bg2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(OnbV2.line, lineWidth: 1)
                        )
                        .onbV2StaggerIn(index: 2, appeared: appeared)

                        Spacer().frame(height: 20)

                        // Sex selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text(Copy.OnboardingV2.s3SexLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(OnbV2.fg3)

                            HStack(spacing: 10) {
                                ForEach(OnbV2Sex.allCases, id: \.self) { s in
                                    sexButton(s)
                                }
                            }
                        }
                        .onbV2StaggerIn(index: 3, appeared: appeared)

                        Spacer().frame(height: 16)

                        Text(Copy.OnboardingV2.s3Microcopy)
                            .font(.system(size: 12))
                            .foregroundStyle(OnbV2.fg4)
                            .lineSpacing(2)
                            .onbV2StaggerIn(index: 4, appeared: appeared)

                        // Pushes the block up so a tall device doesn't strand
                        // the microcopy in the middle of an empty column.
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, minHeight: 0, alignment: .top)
                }

                OnbV2PrimaryCTA(
                    Copy.OnboardingV2.s3CTA,
                    isEnabled: profile.sex != nil
                ) {
                    ctaTapped = true
                    onContinue()
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
                .onbV2StaggerIn(index: 5, appeared: appeared)
            }
        }
        // .selection on every +/- tap and every sex pick; .impact(.light) on CTA.
        .sensoryFeedback(.selection, trigger: profile.age)
        .sensoryFeedback(.selection, trigger: profile.sex)
        .sensoryFeedback(.impact(weight: .light), trigger: ctaTapped)
        .task { appeared = true }
    }

    private func bumpAge(_ delta: Int) {
        if reduceMotion {
            profile.age += delta
        } else {
            withAnimation(.snappy(duration: 0.22)) { profile.age += delta }
        }
    }

    @ViewBuilder
    private func sexButton(_ s: OnbV2Sex) -> some View {
        let isSelected = profile.sex == s
        Button {
            profile.sex = s
        } label: {
            Text(s.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? OnbV2.blue : OnbV2.fg)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                        .fill(isSelected ? OnbV2.blue.opacity(0.12) : OnbV2.bg2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: OnbV2.rMd, style: .continuous)
                        .stroke(isSelected ? OnbV2.blue : OnbV2.line, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.16), value: isSelected)
    }
}

// MARK: - Screen 4: Goal (multi-select)

struct OnbV2Screen4Goal: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var ctaTapped = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 4, total: OnbV2Flow.total, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s4Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .onbV2StaggerIn(index: 0, appeared: appeared)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s4Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .onbV2StaggerIn(index: 1, appeared: appeared)

                        Spacer().frame(height: 24)

                        VStack(spacing: 10) {
                            ForEach(Array(OnbV2Goal.allCases.enumerated()), id: \.element) { idx, goal in
                                let copy = Copy.OnboardingV2.goalCopy[goal]!
                                OnbV2SelectRow(
                                    icon: copy.icon,
                                    title: copy.title,
                                    subtitle: copy.subtitle,
                                    accent: copy.accent,
                                    isSelected: profile.goals.contains(goal)
                                ) {
                                    profile.toggleGoal(goal)
                                }
                                .onbV2StaggerIn(index: idx + 2, appeared: appeared)
                            }
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 10) {
                    Text(profile.goals.isEmpty
                         ? Copy.OnboardingV2.s4ZeroCount
                         : "\(profile.goals.count) selected")
                        .font(.system(size: 12))
                        .foregroundStyle(OnbV2.fg4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        // Tally rolls its digit as goals toggle on/off.
                        .contentTransition(.numericText(value: Double(profile.goals.count)))
                        .animation(.snappy(duration: 0.25), value: profile.goals.count)

                    OnbV2PrimaryCTA(
                        Copy.OnboardingV2.s4CTA,
                        isEnabled: !profile.goals.isEmpty
                    ) {
                        ctaTapped = true
                        onContinue()
                    }
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ctaTapped)
        .task { appeared = true }
    }
}

// MARK: - Screen 5: Symptoms

struct OnbV2Screen5Symptoms: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void

    private var ledeText: Text {
        Text(Copy.OnboardingV2.s5Lede1)
            .foregroundStyle(OnbV2.fg2)
        +
        Text(Copy.OnboardingV2.s5LedeBold)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(OnbV2.fg)
        +
        Text(Copy.OnboardingV2.s5Lede2)
            .foregroundStyle(OnbV2.fg2)
    }

    @State private var appeared = false
    @State private var ctaTapped = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 5, total: OnbV2Flow.total, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s5Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .onbV2StaggerIn(index: 0, appeared: appeared)

                        Spacer().frame(height: 12)

                        ledeText
                            .font(.system(size: 16))
                            .onbV2StaggerIn(index: 1, appeared: appeared)

                        Spacer().frame(height: 24)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 130), spacing: 10)],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            // enumerated() so each chip waves in along reading
                            // order (left-to-right, top-to-bottom) of the grid.
                            ForEach(Array(OnbV2Symptom.allCases.enumerated()), id: \.element) { idx, s in
                                let copy = Copy.OnboardingV2.symptomCopy[s]!
                                OnbV2Chip(
                                    icon: copy.icon,
                                    label: copy.label,
                                    isSelected: profile.symptoms.contains(s)
                                ) {
                                    profile.toggleSymptom(s)
                                }
                                .onbV2StaggerIn(index: idx + 2, appeared: appeared, tight: true)
                            }
                        }

                        // Lets the grid sit under the lede on tall devices.
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, minHeight: 0, alignment: .top)
                }

                VStack(spacing: 10) {
                    Text(profile.symptoms.isEmpty
                         ? Copy.OnboardingV2.s5ZeroCount
                         : "\(profile.symptoms.count) selected")
                        .font(.system(size: 12))
                        .foregroundStyle(OnbV2.fg4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        // Tally rolls its digit as chips toggle on/off.
                        .contentTransition(.numericText(value: Double(profile.symptoms.count)))
                        .animation(.snappy(duration: 0.25), value: profile.symptoms.count)

                    OnbV2PrimaryCTA(Copy.OnboardingV2.s5CTA) {
                        ctaTapped = true
                        onContinue()
                    }
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ctaTapped)
        .task { appeared = true }
    }
}

// MARK: - Screen 6: Activity

struct OnbV2Screen6Activity: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var ctaTapped = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            // Only four rows, so drop the ScrollView and let Spacers centre the
            // block between the header and the CTA instead of leaving a void.
            VStack(spacing: 0) {
                OnbV2TopBar(step: 7, total: OnbV2Flow.total, onBack: onBack)

                VStack(alignment: .leading, spacing: 0) {
                    Text(Copy.OnboardingV2.s6Title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnbV2.fg)
                        .onbV2StaggerIn(index: 0, appeared: appeared)

                    Spacer().frame(height: 12)

                    Text(Copy.OnboardingV2.s6Lede)
                        .font(.system(size: 16))
                        .foregroundStyle(OnbV2.fg2)
                        .onbV2StaggerIn(index: 1, appeared: appeared)

                    Spacer(minLength: 24)

                    VStack(spacing: 10) {
                        ForEach(Array(OnbV2Activity.allCases.enumerated()), id: \.element) { idx, a in
                            let copy = Copy.OnboardingV2.activityCopy[a]!
                            OnbV2SelectRow(
                                icon: copy.icon,
                                title: copy.title,
                                subtitle: copy.subtitle,
                                accent: OnbV2.green,
                                isSelected: profile.activity == a
                            ) {
                                profile.activity = a
                            }
                            .onbV2StaggerIn(index: idx + 2, appeared: appeared)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.top, 24)

                OnbV2PrimaryCTA(
                    Copy.OnboardingV2.s6CTA,
                    isEnabled: profile.activity != nil
                ) {
                    ctaTapped = true
                    onContinue()
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ctaTapped)
        .task { appeared = true }
    }
}

// MARK: - Screen 7: Wearable

struct OnbV2Screen7Wearable: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void
    @State private var appeared = false
    @State private var ctaTapped = false

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue, staggerOwnsEntry: true) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 8, total: OnbV2Flow.total, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s7Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .onbV2StaggerIn(index: 0, appeared: appeared)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s7Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .lineSpacing(2)
                            .onbV2StaggerIn(index: 1, appeared: appeared)

                        Spacer().frame(height: 24)

                        VStack(spacing: 10) {
                            ForEach(Array(OnbV2Wearable.allCases.enumerated()), id: \.element) { idx, w in
                                let copy = Copy.OnboardingV2.wearableCopy[w]!
                                OnbV2SelectRow(
                                    icon: copy.icon,
                                    title: copy.title,
                                    subtitle: copy.subtitle,
                                    accent: OnbV2.blue,
                                    isSelected: profile.wearable == w
                                ) {
                                    profile.wearable = w
                                }
                                .onbV2StaggerIn(index: idx + 2, appeared: appeared)
                            }
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }

                OnbV2PrimaryCTA(
                    Copy.OnboardingV2.s7CTA,
                    isEnabled: profile.wearable != nil
                ) {
                    ctaTapped = true
                    onContinue()
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: ctaTapped)
        .task { appeared = true }
    }
}
