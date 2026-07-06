import SwiftUI

/// Shown when the master kill switch is enabled via Remote Config, or as an
/// informational blocker for a killed surface (e.g. Live tab). Hard block by
/// design: the admin panel labels the master switch "blocks entire app", so
/// there is deliberately no way to dismiss it.
struct MaintenanceView: View {
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text(Copy.Common.underMaintenance)
                .font(.title.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.space7)

            Spacer()
        }
    }
}
