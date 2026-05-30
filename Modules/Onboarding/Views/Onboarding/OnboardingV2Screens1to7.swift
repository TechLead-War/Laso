import SwiftUI

// MARK: - Screen 1: Welcome

struct OnbV2Screen1Welcome: View {
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                OnbV2HeartHero(size: 220)

                Spacer().frame(height: 36)

                Text(Copy.OnboardingV2.s1Eyebrow)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(OnbV2.blue)

                Spacer().frame(height: 14)

                Text(Copy.OnboardingV2.s1Title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(OnbV2.fg)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Spacer().frame(height: 16)

                Text(Copy.OnboardingV2.s1Lede)
                    .font(.system(size: 16))
                    .foregroundStyle(OnbV2.fg2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Spacer(minLength: 0)

                OnbV2PrimaryCTA(Copy.OnboardingV2.s1CTA, action: onContinue)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, OnbV2.bodyPadH)
        }
    }
}

// MARK: - Screen 2: Promise

struct OnbV2Screen2Promise: View {
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 2, total: 16, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s2Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)
                            .lineSpacing(4)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s2Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)

                        Spacer().frame(height: 28)

                        VStack(spacing: 14) {
                            OnbV2PromiseCard(
                                icon: "sparkles",
                                title: Copy.OnboardingV2.s2Card1Title,
                                bodyText: Copy.OnboardingV2.s2Card1Body,
                                accent: OnbV2.blue
                            )
                            OnbV2PromiseCard(
                                icon: "lock.fill",
                                title: Copy.OnboardingV2.s2Card2Title,
                                bodyText: Copy.OnboardingV2.s2Card2Body,
                                accent: OnbV2.green
                            )
                            OnbV2PromiseCard(
                                icon: "heart.fill",
                                title: Copy.OnboardingV2.s2Card3Title,
                                bodyText: Copy.OnboardingV2.s2Card3Body,
                                accent: OnbV2.rose
                            )
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                }

                VStack(spacing: 6) {
                    OnbV2PrimaryCTA(Copy.OnboardingV2.s2CTA, action: onContinue)
                    Text(Copy.OnboardingV2.s2Caption)
                        .font(.system(size: 12))
                        .foregroundStyle(OnbV2.fg4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Screen 3: About

struct OnbV2Screen3About: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 3, total: 16, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s3Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s3Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)

                        Spacer().frame(height: 28)

                        // Age stepper section
                        VStack(alignment: .leading, spacing: 14) {
                            Text(Copy.OnboardingV2.s3AgeLabel)
                                .font(.system(size: 13))
                                .foregroundStyle(OnbV2.fg3)

                            HStack(spacing: 0) {
                                Button {
                                    if profile.age > 13 { profile.age -= 1 }
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
                                    Text(Copy.Onboarding.years)
                                        .font(.system(size: 14))
                                        .foregroundStyle(OnbV2.fg3)
                                }

                                Spacer(minLength: 0)

                                Button {
                                    if profile.age < 110 { profile.age += 1 }
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

                        Spacer().frame(height: 16)

                        Text(Copy.OnboardingV2.s3Microcopy)
                            .font(.system(size: 12))
                            .foregroundStyle(OnbV2.fg4)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }

                OnbV2PrimaryCTA(
                    Copy.OnboardingV2.s3CTA,
                    isEnabled: profile.sex != nil,
                    action: onContinue
                )
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
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

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 4, total: 16, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s4Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s4Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)

                        Spacer().frame(height: 24)

                        VStack(spacing: 10) {
                            ForEach(OnbV2Goal.allCases, id: \.self) { goal in
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

                    OnbV2PrimaryCTA(
                        Copy.OnboardingV2.s4CTA,
                        isEnabled: !profile.goals.isEmpty,
                        action: onContinue
                    )
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
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

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 5, total: 16, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s5Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)

                        Spacer().frame(height: 12)

                        ledeText
                            .font(.system(size: 16))

                        Spacer().frame(height: 24)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 130), spacing: 10)],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(OnbV2Symptom.allCases, id: \.self) { s in
                                let copy = Copy.OnboardingV2.symptomCopy[s]!
                                OnbV2Chip(
                                    icon: copy.icon,
                                    label: copy.label,
                                    isSelected: profile.symptoms.contains(s)
                                ) {
                                    profile.toggleSymptom(s)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }

                VStack(spacing: 10) {
                    Text(profile.symptoms.isEmpty
                         ? Copy.OnboardingV2.s5ZeroCount
                         : "\(profile.symptoms.count) selected")
                        .font(.system(size: 12))
                        .foregroundStyle(OnbV2.fg4)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    OnbV2PrimaryCTA(Copy.OnboardingV2.s5CTA, action: onContinue)
                }
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Screen 6: Activity

struct OnbV2Screen6Activity: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 6, total: 16, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s6Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s6Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)

                        Spacer().frame(height: 24)

                        VStack(spacing: 10) {
                            ForEach(OnbV2Activity.allCases, id: \.self) { a in
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
                            }
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }

                OnbV2PrimaryCTA(
                    Copy.OnboardingV2.s6CTA,
                    isEnabled: profile.activity != nil,
                    action: onContinue
                )
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Screen 7: Wearable

struct OnbV2Screen7Wearable: View {
    let profile: OnboardingV2Profile
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        OnbV2ScreenContainer(ambient: .blue) {
            VStack(spacing: 0) {
                OnbV2TopBar(step: 7, total: 16, onBack: onBack)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Copy.OnboardingV2.s7Title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(OnbV2.fg)

                        Spacer().frame(height: 12)

                        Text(Copy.OnboardingV2.s7Lede)
                            .font(.system(size: 16))
                            .foregroundStyle(OnbV2.fg2)
                            .lineSpacing(2)

                        Spacer().frame(height: 24)

                        VStack(spacing: 10) {
                            ForEach(OnbV2Wearable.allCases, id: \.self) { w in
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
                            }
                        }
                    }
                    .padding(.horizontal, OnbV2.bodyPadH)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }

                OnbV2PrimaryCTA(
                    Copy.OnboardingV2.s7CTA,
                    isEnabled: profile.wearable != nil,
                    action: onContinue
                )
                .padding(.horizontal, OnbV2.bodyPadH)
                .padding(.bottom, 20)
            }
        }
    }
}
