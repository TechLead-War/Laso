import SwiftUI

/// Blocks the app when the current version is below the required minimum.
/// Shown as a full-screen cover that cannot be dismissed.
struct ForceUpdateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Update Required")
                .font(.title.bold())

            Text("A new version of Laso is available with important fixes. Please update to continue.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let url = URL(string: AppSecrets.URLs.manageSubscriptions) {
                // App Store link. in production, replace with your app's direct App Store URL
                Link(destination: url) {
                    Text("Update Now")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}
