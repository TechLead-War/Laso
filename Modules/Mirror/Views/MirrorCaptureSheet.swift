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
    @State private var look: MirrorLook = .original
    @State private var saveFailed = false
    @State private var photosSaveFailed = false
    @State private var score: Int? = ReadinessStore().loadCachedScore()

    /// Screen-sized copy of the capture, plus the colour look currently applied
    /// to it and one thumbnail per look for the strip. All three are built once
    /// per capture so switching looks costs a few milliseconds, not a full
    /// camera frame re-filtered on the main thread.
    @State private var previewBase: UIImage?
    @State private var lookedPreview: UIImage?
    @State private var lookThumbs: [MirrorLook: UIImage] = [:]

    private static let previewMaxPixel: CGFloat = 1080
    private static let lookThumbMaxPixel: CGFloat = 160

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
        // Sits on the root, not on the confirm screen: the copy to Photos
        // finishes after the replay has already replaced it, and a silent
        // failure would leave the user believing the photo is backed up.
        .alert(Copy.Mirror.photosSaveFailed, isPresented: $photosSaveFailed) {
            Button(Copy.Buttons.done, role: .cancel) {}
        }
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

    // MARK: - Look and filter confirm

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
            Image(uiImage: lookedPreview ?? image)
                .resizable()
                .scaledToFit()
                .overlay(
                    MirrorOverlay(
                        filter: filter,
                        date: .now,
                        score: score,
                        streak: stampStreak
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                .padding(.horizontal, DS.space4)

            Spacer(minLength: 0)

            lookStrip
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
        .onAppear { prepareLookPreviews(image) }
        .alert(Copy.Mirror.saveFailed, isPresented: $saveFailed) {
            Button(Copy.Buttons.done, role: .cancel) {}
        }
    }

    /// Colour looks, shown as live thumbnails of this capture: a name alone
    /// ("Fade") does not tell anyone what the photo will look like.
    private var lookStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.space3) {
                ForEach(MirrorLook.allCases) { candidate in
                    Button {
                        select(candidate)
                    } label: {
                        VStack(spacing: DS.space1) {
                            lookThumb(candidate)
                            Text(candidate.label)
                                .font(DS.Typography.caption)
                                .foregroundStyle(look == candidate ? .white : .white.opacity(0.6))
                        }
                    }
                    .accessibilityAddTraits(look == candidate ? .isSelected : [])
                }
            }
            .padding(.horizontal, DS.space4)
        }
        .sensoryFeedback(.selection, trigger: look)
    }

    @ViewBuilder
    private func lookThumb(_ candidate: MirrorLook) -> some View {
        let side: CGFloat = 52
        Group {
            if let thumb = lookThumbs[candidate] {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.white.opacity(0.15)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .strokeBorder(look == candidate ? Color.white : .clear, lineWidth: 2)
        }
    }

    /// Data overlays. Scrollable because the row no longer fits on one screen,
    /// and score-only overlays are dropped on a day with no score.
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.space2) {
                ForEach(MirrorFilter.available(hasScore: score != nil)) { candidate in
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
            .padding(.horizontal, DS.space4)
        }
        .padding(.bottom, DS.space4)
        .sensoryFeedback(.selection, trigger: filter)
    }

    private func select(_ candidate: MirrorLook) {
        look = candidate
        guard let previewBase else { return }
        lookedPreview = MirrorLookRenderer.apply(candidate, to: previewBase)
    }

    private func prepareLookPreviews(_ image: UIImage) {
        let base = MirrorPhotoStore.downscaled(image, maxPixel: Self.previewMaxPixel)
        previewBase = base
        lookedPreview = MirrorLookRenderer.apply(look, to: base)

        let thumbBase = MirrorPhotoStore.downscaled(base, maxPixel: Self.lookThumbMaxPixel)
        lookThumbs = Dictionary(uniqueKeysWithValues: MirrorLook.allCases.map {
            ($0, MirrorLookRenderer.apply($0, to: thumbBase))
        })
    }

    private func save(_ image: UIImage) {
        let streak = stampStreak
        // Colour first, overlay second: the stamp must stay legible white on
        // black, not get pushed through a mono or fade filter with the photo.
        let looked = MirrorLookRenderer.apply(look, to: image)
        let finished = MirrorPhotoRenderer.render(
            photo: looked, filter: filter, date: .now, score: score, streak: streak
        )
        do {
            try store.save(finished, score: score, streak: streak)
            if MirrorPhotoLibrary.isEnabled {
                Task {
                    if await MirrorPhotoLibrary.save(finished) == false {
                        photosSaveFailed = true
                    }
                }
            }
            // A capture from any door ends the prompt's quiet period and
            // dismissal count: the user is engaged again.
            MirrorMomentManager.shared.recordCaptured()
            AppAnalytics.shared.trackBlockTap(
                title: "Save mirror photo",
                type: .mirrorPhotoSaved,
                screen: .mirrorCapture,
                metadata: [
                    "filter": filter.rawValue,
                    "look": look.rawValue,
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
