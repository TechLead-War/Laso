import SwiftUI

/// Full-screen loading state with animated syncing phases
struct LoadingView: View {
    @State private var currentPhase = 1
    @State private var dotCount = 0
    @State private var activeDots = 0
    @State private var iconScale: CGFloat = 0.8
    @State private var iconOpacity: Double = 0.6
    /// Counts ticks so we can advance the phase every 2nd tick (~1.8s at 0.9s interval).
    @State private var tickCount = 0

    let message: String

    private let phases: [(icon: String, text: String, color: Color)] = [
        ("antenna.radiowaves.left.and.right", "Connecting to Apple Health", .blue),
        ("heart.fill", "Syncing heart data", .red),
        ("bed.double.fill", "Reading sleep patterns", .indigo),
        ("figure.run", "Loading activity data", .orange),
        ("brain.head.profile", "Analyzing recovery", .purple),
        ("sparkles", "Almost ready", .green),
    ]

    /// When true, repeating animations are suppressed to reduce GPU load.
    private var thermallyConstrained: Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    init(_ message: String = "Loading health data...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated icon with glow
            ZStack {
                // Glow ring. one-shot scale on appear (no repeatForever)
                Circle()
                    .fill(currentColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconScale == 1.0 ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 1.2), value: iconScale)

                Circle()
                    .fill(currentColor.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .scaleEffect(iconScale == 1.0 ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 1.5), value: iconScale)

                // Icon
                Image(systemName: phases[currentPhase].icon)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(currentColor)
                    .frame(width: 80, height: 80)
                    .background(currentColor.opacity(0.12), in: Circle())
                    .scaleEffect(iconScale)
                    .opacity(iconOpacity)
                    .contentTransition(.symbolEffect(.replace))
            }

            // Phase text with animated dots
            VStack(spacing: 8) {
                Text(phases[currentPhase].text + animatedDots)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: currentPhase)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Progress dots. fills up 1→2→3→4→5→6 then resets
            HStack(spacing: 6) {
                ForEach(0..<phases.count, id: \.self) { index in
                    let isActive = index < activeDots
                    Circle()
                        .fill(isActive ? currentColor : Color.secondary.opacity(0.2))
                        .frame(width: isActive && index == activeDots - 1 ? 8 : 6,
                               height: isActive && index == activeDots - 1 ? 8 : 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: activeDots)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            currentPhase = min(1, phases.count - 1)

            if thermallyConstrained {
                iconScale = 1.0
                iconOpacity = 1.0
            } else {
                withAnimation(.easeInOut(duration: 0.6)) {
                    iconScale = 1.0
                    iconOpacity = 1.0
                }
            }

            // Auto-cancelled when the view is removed from the hierarchy.
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { break }
                tick()
            }
        }
    }

    private var currentColor: Color {
        phases[currentPhase].color
    }

    private var animatedDots: String {
        String(repeating: ".", count: dotCount)
    }

    // MARK: - Tick

    private func tick() {
        tickCount += 1

        // Cycle dots every tick: 1 → 2 → 3 → 1 ...
        dotCount = (dotCount % 3) + 1

        // Advance progress dots every tick
        withAnimation {
            if activeDots >= phases.count {
                activeDots = 0
            } else {
                activeDots += 1
            }
        }

        // Advance phase every 2nd tick (~1.8s, matching original interval)
        if tickCount % 2 == 0 {
            withAnimation(.easeInOut(duration: 0.4)) {
                if currentPhase < phases.count - 1 {
                    currentPhase += 1
                } else {
                    currentPhase = min(1, phases.count - 1)
                }
            }
        }
    }
}

#Preview {
    LoadingView("Analyzing your health data...")
}
