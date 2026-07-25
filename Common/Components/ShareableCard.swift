import SwiftUI
import PhotosUI

/// Card type for shareable content
enum ShareCardType {
    case score(score: Int, scoreChange: Int?, streakDays: Int)
    case insight(text: String, metric: String, category: String)
    case rings(vitalityAge: Int?, realAge: Int?, recovery: Int?, sleepSeconds: Double?, photo: UIImage?)
}

// MARK: - Rings Card (Whoop-style photo share)

/// A story-sized (9:16) card: the user's own photo (or a brand gradient when
/// they skip), with up to three stat rings across the lower third — Vitality
/// Age, Recovery, and last night's sleep. Rings with no data are hidden;
/// nothing is invented.
struct ShareableRingsCard: View {
    let vitalityAge: Int?
    let realAge: Int?
    let recovery: Int?
    let sleepSeconds: Double?
    let photo: UIImage?

    /// Mirrors the fixed goal in `RecoverySignalsSnapshot.sleepHoursGoal`.
    private static let sleepGoalHours: Double = 7.5

    private var gradientColors: [Color] {
        let score = recovery ?? 0
        switch score {
        case 80...100: return [AppColour.shareScoreHighStart, AppColour.shareScoreHighEnd]
        case 60..<80: return [AppColour.shareScoreGoodStart, AppColour.shareScoreGoodEnd]
        case 40..<60: return [AppColour.shareScoreFairStart, AppColour.shareScoreFairEnd]
        default: return [AppColour.shareScorePoorStart, AppColour.shareScorePoorEnd]
        }
    }

    /// Full ring at 10+ years younger, half at on-age, empty at 10+ years older.
    private var vitalityProgress: Double {
        guard let vitalityAge, let realAge else { return 0 }
        let clamped = max(-10, min(10, realAge - vitalityAge))
        return Double(clamped + 10) / 20.0
    }

    private var sleepText: String {
        guard let sleepSeconds, sleepSeconds > 0 else { return "" }
        let h = Int(sleepSeconds / 3600)
        let m = Int((sleepSeconds - Double(h) * 3600) / 60)
        return "\(h):\(String(format: "%02d", m))"
    }

    var body: some View {
        ZStack {
            if let photo {
                // The fill image must be framed and clipped HERE: unframed it
                // inflates the ZStack's layout bounds, which spreads the rings
                // row beyond the visible card and cuts the metrics off.
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 390, height: 693)
                    .clipped()
            } else {
                LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            // Readability fades over the photo, top and bottom.
            LinearGradient(stops: [
                .init(color: .black.opacity(0.45), location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: .clear, location: 0.55),
                .init(color: .black.opacity(0.55), location: 1)
            ], startPoint: .top, endPoint: .bottom)

            VStack(spacing: 0) {
                HStack {
                    Text(Copy.Common.laso.uppercased())
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                }
                .padding(.horizontal, DS.space6)
                .padding(.top, 30)

                Spacer()

                HStack(spacing: 0) {
                    if let vitalityAge {
                        statRing(value: "\(vitalityAge)",
                                 label: Copy.Common.shareRingVitalityAge,
                                 progress: vitalityProgress,
                                 tint: AppColour.scoreOptimal)
                    }
                    if let recovery {
                        statRing(value: "\(recovery)",
                                 label: Copy.Common.shareRingRecovery,
                                 progress: Double(recovery) / 100.0,
                                 tint: DS.scoreColor(recovery))
                    }
                    if let sleepSeconds, sleepSeconds > 0 {
                        statRing(value: sleepText,
                                 label: Copy.Common.shareRingSleep,
                                 progress: min((sleepSeconds / 3600) / Self.sleepGoalHours, 1),
                                 tint: .white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.space4)

                Spacer().frame(height: 26)

                Text(Copy.Common.shareCardFooter)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 26)
            }
        }
        .frame(width: 390, height: 693)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private func statRing(value: String, label: String, progress: Double, tint: Color) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 7)
                    .frame(width: 92, height: 92)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 92, height: 92)
                Text(value)
                    .font(.system(size: value.count > 2 ? 24 : 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 4)
            }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Camera capture

/// Minimal camera wrapper for the share card's "take a photo" option. iOS
/// shows the camera permission prompt on first use; a denial simply returns
/// the user to the sheet with no photo.
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Rings share flow (photo pick -> preview -> share)

/// Sheet presented from the home Recovery card's share icon. Shows a live
/// preview of the rings card, lets the user attach a photo via the system
/// photo picker (no permission prompt needed), and hands the rendered image
/// to the share sheet through `ShareButton`.
struct ShareRingsSheet: View {
    let vitalityAge: Int?
    let realAge: Int?
    let recovery: Int?
    let sleepSeconds: Double?

    @State private var photoItem: PhotosPickerItem?
    @State private var photo: UIImage?
    @State private var showCamera = false
    @Environment(\.dismiss) private var dismiss

    /// Referral invite line attached as text next to the image. The card image
    /// itself stays clean; message apps show this under the photo.
    private var inviteCaption: String? {
        let referral = ReferralManager.shared
        guard referral.isEnabled, let code = referral.referralCode else { return nil }
        if let vitalityAge, let realAge, vitalityAge < realAge {
            return Copy.Referral.shareCaptionYounger(years: realAge - vitalityAge, code: code)
        }
        return Copy.Referral.shareCaptionGeneric(code: code)
    }

    var body: some View {
        VStack(spacing: DS.space4) {
            Text(Copy.Common.shareSheetTitle)
                .font(DS.Typography.title3)
                .foregroundStyle(AppColour.textPrimary)
                .padding(.top, DS.space5)

            ShareableRingsCard(
                vitalityAge: vitalityAge,
                realAge: realAge,
                recovery: recovery,
                sleepSeconds: sleepSeconds,
                photo: photo
            )
            .scaleEffect(0.62)
            .frame(width: 390 * 0.62, height: 693 * 0.62)

            HStack(spacing: DS.space5) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(photo == nil ? Copy.Common.shareAddPhoto : Copy.Common.shareChangePhoto,
                          systemImage: "photo")
                        .font(DS.Typography.bodySemibold)
                }
                .onChange(of: photoItem) { _, item in
                    guard let item else { return }
                    let wasChange = photo != nil
                    Task { @MainActor in
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            photo = image
                            AppAnalytics.shared.trackSharePhotoAdded(source: "library", isChange: wasChange)
                        }
                    }
                }

                // Camera capture, hidden where no camera exists (simulator).
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label(Copy.Common.shareTakePhoto, systemImage: "camera")
                            .font(DS.Typography.bodySemibold)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraCaptureView { image in
                    let wasChange = photo != nil
                    photo = image
                    AppAnalytics.shared.trackSharePhotoAdded(source: "camera", isChange: wasChange)
                }
                .ignoresSafeArea()
            }

            ShareButton(
                cardType: .rings(vitalityAge: vitalityAge, realAge: realAge,
                                 recovery: recovery, sleepSeconds: sleepSeconds, photo: photo),
                screen: .home,
                title: Copy.Common.shareCTA,
                captionText: inviteCaption
            )

            Spacer(minLength: DS.space4)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            // Mint/load the invite code before the user hits Share so the
            // caption can carry it. No-op when cached or program disabled.
            await ReferralManager.shared.ensureReferralCode()
        }
    }
}

// MARK: - Score Card

/// A shareable card displaying the user's health score, weekly change, and streak
struct ShareableScoreCard: View {
    let score: Int
    let scoreChange: Int?
    let streakDays: Int

    private var scoreColor: Color {
        DS.scoreColor(score)
    }

    private var gradientColors: [Color] {
        switch score {
        case 80...100: return [AppColour.shareScoreHighStart, AppColour.shareScoreHighEnd]
        case 60..<80: return [AppColour.shareScoreGoodStart, AppColour.shareScoreGoodEnd]
        case 40..<60: return [AppColour.shareScoreFairStart, AppColour.shareScoreFairEnd]
        default: return [AppColour.shareScorePoorStart, AppColour.shareScorePoorEnd]
        }
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Top bar: App name
                HStack {
                    Text(Copy.Common.laso)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, DS.space6)
                .padding(.top, 28)

                Spacer()

                // Center: Score ring
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(scoreColor.opacity(0.08))
                        .frame(width: 200, height: 200)

                    // Background ring
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 14)
                        .frame(width: 160, height: 160)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: Double(score) / 100.0)
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 160, height: 160)

                    // Score number
                    VStack(spacing: 2) {
                        Text(Copy.Common.xText(score))
                            .font(DS.Typography.displayXL)
                            .foregroundStyle(.white)
                        Text(Copy.Common.healthScore)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer().frame(height: 24)

                // Badges row
                HStack(spacing: 12) {
                    if let change = scoreChange, change != 0 {
                        HStack(spacing: 4) {
                            Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(change > 0 ? "+" : "")\(change) this week")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(change > 0 ? .green : .red)
                        .padding(.horizontal, DS.space3)
                        .padding(.vertical, 6)
                        .background((change > 0 ? Color.green : Color.red).opacity(0.15), in: Capsule())
                    }

                    if streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(Copy.Common.dayStreakText(streakDays))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DS.space3)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.15), in: Capsule())
                    }
                }

                Spacer()

                // Bottom tagline
                Text(Copy.Common.trackYourHealthWithLaso)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // Locale-aware. `.dateTime.day().month().year()` resolves the
    // ordering / separators / month-name length per `Locale.current` (e.g.
    // "Apr 25, 2026" en-US, "25 Apr 2026" en-GB, "25 avr. 2026" fr-FR).
    private var formattedDate: String {
        Date().formatted(.dateTime.day().month().year())
    }
}

// MARK: - Insight Card

/// A shareable card displaying a health insight discovery
struct ShareableInsightCard: View {
    let insightText: String
    let metricName: String
    let category: String

    private var categoryColor: Color {
        // Map category string to HealthCategory color
        switch category.lowercased() {
        case "heart", "heart & cardio": return .red
        case "sleep": return .indigo
        case "activity": return .green
        case "body", "body & vitals": return .orange
        case "respiratory": return .teal
        case "mindfulness": return .cyan
        case "mobility": return .purple
        case "nutrition": return .brown
        default: return .blue
        }
    }

    private var categoryIcon: String {
        switch category.lowercased() {
        case "heart", "heart & cardio": return "heart.fill"
        case "sleep": return "bed.double.fill"
        case "activity": return "figure.run"
        case "body", "body & vitals": return "figure.stand"
        case "respiratory": return "lungs.fill"
        case "mindfulness": return "brain.head.profile"
        case "mobility": return "figure.walk.motion"
        case "nutrition": return "fork.knife"
        default: return "sparkles"
        }
    }

    private var gradientColors: [Color] {
        [categoryColor.opacity(0.25), AppColour.shareSecondaryBackground]
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Top bar: App name
                HStack {
                    Text(Copy.Common.laso2)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, DS.space6)
                .padding(.top, 28)

                Spacer()

                // Insight icon
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 80, height: 80)

                    Image(systemName: categoryIcon)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(categoryColor)
                }

                Spacer().frame(height: 20)

                // Category badge
                Text(category)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(categoryColor)
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(categoryColor.opacity(0.15), in: Capsule())

                Spacer().frame(height: 20)

                // Main insight text
                Text(insightText)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, DS.space7)

                Spacer().frame(height: 12)

                // Metric label
                Text(metricName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                // Bottom tagline
                Text(Copy.Common.discoverYourHealthPatternsWithLaso)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 28)
            }
        }
        .frame(width: 390, height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    // Locale-aware (see notes on the score-card formatter above).
    private var formattedDate: String {
        Date().formatted(.dateTime.day().month().year())
    }
}

// MARK: - Previews

#Preview("Score Card - High") {
    ShareableScoreCard(score: 85, scoreChange: 5, streakDays: 14)
        .padding()
        .background(.black)
}

#Preview("Score Card - Medium") {
    ShareableScoreCard(score: 62, scoreChange: -3, streakDays: 0)
        .padding()
        .background(.black)
}

#Preview("Insight Card") {
    ShareableInsightCard(
        insightText: "Your resting heart rate has been trending down over the past 2 weeks",
        metricName: "Resting Heart Rate",
        category: "Heart"
    )
    .padding()
    .background(.black)
}
