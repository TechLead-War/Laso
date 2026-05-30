import SwiftUI

/// Blocking screen shown when the app detects a compromised device environment
/// (jailbreak, debugger, tampered binary, or emulator in release mode).
/// Cannot be dismissed. the app is non-functional in this state.
struct CompromisedEnvironmentView: View {
    let reason: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)

                Text(Copy.Common.securityCheckFailed)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(Copy.Common.thisAppCannotRunOnA)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Text(Copy.Common.errorText(reason))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary.opacity(0.5))

                Spacer()

                Text(Copy.Common.ifYouBelieveThisIsAn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .interactiveDismissDisabled()
    }
}
