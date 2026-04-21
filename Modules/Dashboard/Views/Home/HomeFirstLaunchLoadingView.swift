import SwiftUI

struct HomeFirstLaunchLoadingView: View {
    let syncPhase: DashboardViewModel.SyncPhase
    let totalDataPoints: Int

    @State private var iconScale: CGFloat = 0.8
    @State private var dotCount = 0
    @State private var appeared = false
    @State private var dotTimer: Timer?

    private var phase: (icon: String, text: String, color: Color) {
        switch syncPhase {
        case .idle, .importing:
            return ("brain.head.profile", Copy.Home.syncingHealthData, .purple)
        case .analyzing:
            let label = totalDataPoints > 0 ? Copy.Home.analyzingDataPoints(totalDataPoints) : Copy.Home.analyzingYourData
            return ("brain.head.profile", label, .purple)
        case .discovering:
            return ("sparkles", Copy.Home.discoveringPatterns, .orange)
        case .complete:
            return ("checkmark.circle.fill", Copy.Home.ready, .green)
        }
    }

    var body: some View {
        let p = phase
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(p.color.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(iconScale == 1.0 ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: iconScale)

                Circle()
                    .fill(p.color.opacity(0.05))
                    .frame(width: 160, height: 160)
                    .scaleEffect(iconScale == 1.0 ? 1.5 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: iconScale)

                Image(systemName: p.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(p.color)
                    .frame(width: 80, height: 80)
                    .background(p.color.opacity(0.12), in: Circle())
                    .scaleEffect(iconScale)
                    .contentTransition(.symbolEffect(.replace))
            }

            VStack(spacing: 8) {
                Text(p.text + String(repeating: ".", count: dotCount))
                    .font(.system(size: 18).weight(.medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: syncPhase)

                Text(Copy.Home.thisOnlyHappensOnce)
                    .font(.system(size: 14.4))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            appeared = true
            iconScale = 1.0
            startDotTimer()
        }
        .onDisappear {
            appeared = false
            stopDotTimer()
        }
    }

    private func startDotTimer() {
        stopDotTimer()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard appeared else {
                timer.invalidate()
                return
            }
            dotCount = (dotCount % 3) + 1
        }
        timer.tolerance = 0.1
        dotTimer = timer
    }

    private func stopDotTimer() {
        dotTimer?.invalidate()
        dotTimer = nil
    }
}


