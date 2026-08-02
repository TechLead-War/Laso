import SwiftUI

/// The Daily Mirror capture flow, presented full screen from the journal
/// check-in card: privacy explainer (first run only), camera, filter confirm,
/// then the seven day replay as the save reward.
struct MirrorCaptureSheet: View {
    @Environment(\.dismiss) private var dismiss

    private enum Stage {
        case explainer
        case camera
        case confirm(UIImage)
        case replay
    }

    @State private var stage: Stage
    @State private var filter: MirrorFilter = .stamp
    @State private var saveFailed = false

    private let store = MirrorPhotoStore.shared

    /// The streak the finished photo is stamped with. On a retake, today is
    /// already inside currentStreak, so adding one would bake tomorrow's
    /// number into today's photo.
    private var stampStreak: Int {
        store.hasPhoto(on: .now) ? store.currentStreak : store.currentStreak + 1
    }

    init() {
        let seen = UserDefaults.standard.bool(forKey: AppKeys.Mirror.explainerSeen)
        _stage = State(initialValue: seen ? .camera : .explainer)
    }

    var body: some View {
        ZStack {
            AppColour.surfaceBase.ignoresSafeArea()

            switch stage {
            case .explainer:
                explainer
            case .camera:
                CameraCaptureView(cameraDevice: .front, dismissesOnCapture: false) { image in
                    stage = .confirm(image)
                }
                .ignoresSafeArea()
            case .confirm(let image):
                confirm(image)
            case .replay:
                MirrorReplayView { dismiss() }
            }
        }
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.mirrorCapture) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.mirrorCapture) }
    }

    // MARK: - First run explainer

    private var explainer: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(DS.Typography.heroIcon)
                .foregroundStyle(AppColour.primary)
                .padding(.bottom, DS.space5)

            Text(Copy.Mirror.explainerTitle)
                .font(DS.Typography.title2)
                .foregroundStyle(AppColour.textPrimary)
                .multilineTextAlignment(.center)

            Text(Copy.Mirror.explainerBody)
                .font(DS.Typography.subheadline)
                .foregroundStyle(AppColour.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, DS.space2)

            VStack(alignment: .leading, spacing: DS.space3) {
                explainerPoint(Copy.Mirror.explainerPoint1, icon: "checkmark", tint: AppColour.success)
                explainerPoint(Copy.Mirror.explainerPoint2, icon: "checkmark", tint: AppColour.success)
                explainerPoint(Copy.Mirror.explainerPoint3, icon: "exclamationmark", tint: AppColour.warning)
            }
            .padding(.top, DS.space6)

            Spacer()

            Button {
                UserDefaults.standard.set(true, forKey: AppKeys.Mirror.explainerSeen)
                AppAnalytics.shared.trackBlockTap(
                    title: "Allow camera and start",
                    type: .mirrorCaptureStarted,
                    screen: .mirrorCapture
                )
                stage = .camera
            } label: {
                Text(Copy.Mirror.explainerStart)
                    .font(DS.Typography.headline)
                    .foregroundStyle(AppColour.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space4)
                    .background(AppColour.primary, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            }
            .buttonStyle(.dsPress)

            Button(Copy.Mirror.explainerLater) { dismiss() }
                .font(DS.Typography.subheadlineMedium)
                .foregroundStyle(AppColour.textTertiary)
                .padding(.vertical, DS.space4)
        }
        .padding(.horizontal, DS.space6)
    }

    private func explainerPoint(_ text: String, icon: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: DS.space3) {
            Image(systemName: icon)
                .font(DS.Typography.footnoteMedium)
                .foregroundStyle(tint)
                .frame(width: DS.space6, height: DS.space6)
                .background(AppColour.surfaceRaised, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
            Text(text)
                .font(DS.Typography.footnote)
                .foregroundStyle(AppColour.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Filter confirm

    private func confirm(_ image: UIImage) -> some View {
        VStack(spacing: DS.space4) {
            HStack {
                Button(Copy.Mirror.confirmRetake) { stage = .camera }
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.space4)
                    .padding(.vertical, DS.space2)
                    .background(.white.opacity(0.15), in: Capsule())
                Spacer()
            }
            .padding(.horizontal, DS.space4)
            .padding(.top, DS.space4)

            Spacer(minLength: 0)

            // Fitted preview, not full bleed: the whole photo stays visible and
            // the stamp can never collide with the controls below. The overlay
            // sizes to the fitted photo rect, which is exactly the rect the
            // baked JPEG uses.
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay(
                    MirrorOverlay(
                        filter: filter,
                        date: .now,
                        score: ReadinessStore().loadCachedScore(),
                        streak: stampStreak
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                .padding(.horizontal, DS.space4)

            Spacer(minLength: 0)

            filterChips

            Button {
                save(image)
            } label: {
                Text(Copy.Mirror.confirmSave)
                    .font(DS.Typography.headline)
                    .foregroundStyle(AppColour.textOnAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.space4)
                    .background(AppColour.primary, in: RoundedRectangle(cornerRadius: DS.cardRadius))
            }
            .buttonStyle(.dsPress)
            .padding(.horizontal, DS.space6)
            .padding(.bottom, DS.space5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .alert(Copy.Mirror.saveFailed, isPresented: $saveFailed) {
            Button(Copy.Buttons.done, role: .cancel) {}
        }
    }

    private var filterChips: some View {
        HStack(spacing: DS.space2) {
            ForEach(MirrorFilter.allCases) { candidate in
                Button {
                    filter = candidate
                } label: {
                    Text(candidate.label)
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(filter == candidate ? Color.black : .white)
                        .padding(.horizontal, DS.space3)
                        .padding(.vertical, DS.space2)
                        .background(
                            filter == candidate ? Color.white : .white.opacity(0.15),
                            in: Capsule()
                        )
                }
                .accessibilityAddTraits(filter == candidate ? .isSelected : [])
            }
        }
        .padding(.bottom, DS.space4)
        .sensoryFeedback(.selection, trigger: filter)
    }

    private func save(_ image: UIImage) {
        let score = ReadinessStore().loadCachedScore()
        let streak = stampStreak
        let finished = MirrorPhotoRenderer.render(
            photo: image, filter: filter, date: .now, score: score, streak: streak
        )
        do {
            try store.save(finished, score: score, streak: streak)
            // A capture from any door ends the prompt's quiet period and
            // dismissal count: the user is engaged again.
            MirrorMomentManager.shared.recordCaptured()
            AppAnalytics.shared.trackBlockTap(
                title: "Save mirror photo",
                type: .mirrorPhotoSaved,
                screen: .mirrorCapture,
                metadata: [
                    "filter": filter.rawValue,
                    "streak": streak,
                    "has_score": score != nil
                ]
            )
            stage = .replay
        } catch {
            saveFailed = true
        }
    }
}

/// Flicks through the last seven captured days, newest last, then holds on
/// today. Tapping advances immediately; Done closes the flow.
struct MirrorReplayView: View {
    let onDone: () -> Void

    @State private var index = 0

    private let days: [Date] = Array(MirrorPhotoStore.shared.allDays.suffix(7))

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if days.indices.contains(index),
               let image = MirrorPhotoStore.shared.image(on: days[index]) {
                GeometryReader { proxy in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
            }

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Mirror.replayTitle)
                            .font(DS.Typography.captionSemibold)
                            .foregroundStyle(.white.opacity(0.7))
                        if days.indices.contains(index) {
                            Text(days[index].formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                                .font(DS.Typography.title3)
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }
                    }
                    Spacer()
                    Button(Copy.Mirror.replayDone) { onDone() }
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.space4)
                        .padding(.vertical, DS.space2)
                        .background(.black.opacity(0.55), in: Capsule())
                }
                .padding(DS.space4)

                Spacer()

                HStack(spacing: DS.space1) {
                    ForEach(days.indices, id: \.self) { dayIndex in
                        Capsule()
                            .fill(dayIndex == index ? Color.white : .white.opacity(0.35))
                            .frame(width: dayIndex == index ? 16 : 5, height: 5)
                    }
                }
                .padding(.bottom, DS.space6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .task {
            // One flick per day. Ends holding on the newest photo, no loop.
            while !Task.isCancelled && index < days.count - 1 {
                try? await Task.sleep(for: .seconds(0.7))
                guard !Task.isCancelled else { return }
                advance()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: index)
    }

    private func advance() {
        guard index < days.count - 1 else { return }
        index += 1
    }
}
