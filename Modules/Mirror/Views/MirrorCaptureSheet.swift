import SwiftUI

/// The Daily Mirror capture flow, presented full screen from the journal
/// check-in card: privacy explainer (first run only), camera, template confirm,
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
    @State private var template: MirrorTemplate = MirrorHouseLook.current
    @State private var saveFailed = false
    @State private var photosSaveFailed = false

    /// Filled once the captured frame has been measured. Until then the picker
    /// shows the templates that need no measurement and the ladder falls back
    /// to its safe step, so nothing ever waits on Vision to draw something.
    @State private var analysis = MirrorLegibility.Analysis.unknown
    @State private var personMask: UIImage?
    @State private var payload = MirrorPayload.empty
    @State private var suggested: MirrorTemplate?
    @State private var suggestionReason: String?

    private let store = MirrorPhotoStore.shared

    /// The streak the finished photo is stamped with. On a retake, today is
    /// already inside currentStreak, so adding one would bake tomorrow's
    /// number into today's photo.
    private var stampStreak: Int {
        store.hasPhoto(on: .now) ? store.currentStreak : store.currentStreak + 1
    }

    init() {
        if UITestMode.isEnabled, let raw = UITestMode.mirrorConfirmFilter,
           let photo = MirrorPhotoStore.shared.image(on: .now) {
            _stage = State(initialValue: .confirm(photo))
            _template = State(initialValue: MirrorTemplate(rawValue: raw) ?? .fieldNotes)
            return
        }
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

    // MARK: - Template confirm

    private var archiveFacts: MirrorTemplate.ArchiveFacts {
        MirrorTemplate.ArchiveFacts.from(store: store, streak: stampStreak)
    }

    private var offered: [MirrorTemplate] {
        let available = MirrorTemplate.available(payload: payload, archive: archiveFacts)
        // The suggestion leads the row, then the rest in declaration order, so
        // the list never reshuffles under the user between two captures.
        guard let suggested, available.contains(suggested) else { return available }
        return [suggested] + available.filter { $0 != suggested }
    }

    private func confirm(_ image: UIImage) -> some View {
        VStack(spacing: DS.space3) {
            HStack {
                Button(Copy.Mirror.confirmRetake) { retake() }
                    .font(DS.Typography.subheadlineSemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.space4)
                    .padding(.vertical, DS.space2)
                    .background(.white.opacity(0.15), in: Capsule())
                Spacer()
                if template != MirrorHouseLook.current {
                    Button(Copy.Mirror.pickerSetDefault) {
                        MirrorHouseLook.current = template
                    }
                    .font(DS.Typography.captionSemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.space3)
                    .padding(.vertical, DS.space2)
                    .background(.white.opacity(0.15), in: Capsule())
                }
            }
            .padding(.horizontal, DS.space4)
            .padding(.top, DS.space4)

            Spacer(minLength: 0)

            // Fitted preview, not full bleed: the whole photo stays visible and
            // the overlay can never collide with the controls below. The frame
            // sizes to the fitted photo rect, which is exactly the rect the
            // exported JPEG uses.
            preview(image)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, DS.space4)

            Spacer(minLength: 0)

            picker(image)

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
        .task(id: image) { await measure(image) }
        .alert(Copy.Mirror.saveFailed, isPresented: $saveFailed) {
            Button(Copy.Buttons.done, role: .cancel) {}
        }
    }

    private func preview(_ image: UIImage) -> some View {
        // The photo keeps its own aspect so nothing is cropped away before the
        // user has agreed to it.
        Color.clear
            .aspectRatio(image.size.width / max(image.size.height, 1), contentMode: .fit)
            .overlay {
                MirrorPhotoFrame(
                    photo: image,
                    template: template,
                    payload: payload,
                    analysis: analysis,
                    archive: MirrorArchiveSlice.build(for: template.archiveNeed, endingOn: .now),
                    personMask: personMask
                )
            }
            .clipped()
    }

    /// Live previews rather than word chips. A choice you can see is a choice
    /// people actually make, and the row stops being a list nobody reads past
    /// the fourth item of.
    private func picker(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: DS.space2) {
            if let suggestionReason, template == suggested {
                Text(suggestionReason)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, DS.space4)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.space2) {
                    ForEach(offered) { candidate in
                        Button {
                            template = candidate
                            MirrorHouseLook.markSeen(candidate)
                        } label: {
                            card(candidate, image: image)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(candidate.label)
                        .accessibilityIdentifier("mirror.template.\(candidate.rawValue)")
                        .accessibilityAddTraits(template == candidate ? .isSelected : [])
                    }
                }
                .padding(.horizontal, DS.space4)
            }
            .sensoryFeedback(.selection, trigger: template)
        }
        .padding(.bottom, DS.space3)
    }

    private func card(_ candidate: MirrorTemplate, image: UIImage) -> some View {
        let isOn = template == candidate
        return VStack(spacing: DS.space2) {
            MirrorPhotoFrame(
                photo: image,
                template: candidate,
                payload: payload,
                analysis: analysis,
                archive: MirrorArchiveSlice.build(for: candidate.archiveNeed, endingOn: .now),
                personMask: personMask
            )
            .frame(width: 64, height: 85)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .strokeBorder(AppColour.primary, lineWidth: isOn ? 2 : 0)
                    .padding(-2)
            }
            .overlay(alignment: .topTrailing) {
                // One dot, once, on something never tried. It disappears after
                // a single use and it never nags.
                if MirrorHouseLook.isUnseen(candidate) && !isOn {
                    Circle()
                        .fill(AppColour.primary)
                        .frame(width: 5, height: 5)
                        .padding(4)
                }
            }

            Text(candidate.label)
                .font(DS.Typography.caption2Medium)
                .foregroundStyle(isOn ? .white : .white.opacity(0.55))
                .lineLimit(1)
                .frame(width: 68)
        }
    }

    // MARK: - Work

    /// Measures the frame once, then picks the template the day asks for. The
    /// user can be looking at, and changing, the preview the whole time.
    private func measure(_ image: UIImage) async {
        payload = MirrorPayloadBuilder.build(streak: stampStreak)

        let measured = await MirrorLegibility.analyse(image)
        guard !Task.isCancelled else { return }
        analysis = measured

        let pick = MirrorTemplate.suggested(
            payload: payload,
            archive: archiveFacts,
            houseLook: MirrorHouseLook.current,
            lighting: MirrorLegibility.difficulty(measured)
        )
        suggested = pick
        suggestionReason = MirrorTemplate.suggestionReason(
            payload: payload, archive: archiveFacts,
            lighting: MirrorLegibility.difficulty(measured), picked: pick
        )
        template = pick

        // Only one template needs the cutout, so the cost is only paid when it
        // is actually on offer.
        if MirrorTemplate.available(payload: payload, archive: archiveFacts).contains(.behindYou) {
            let mask = await MirrorLegibility.personMask(image)
            guard !Task.isCancelled else { return }
            personMask = mask
        }
    }

    private func retake() {
        analysis = .unknown
        personMask = nil
        suggested = nil
        suggestionReason = nil
        stage = .camera
    }

    private func save(_ image: UIImage) {
        let streak = stampStreak
        do {
            try store.save(
                image, score: payload.score, streak: streak,
                template: template, payload: payload,
                personMask: template == .behindYou ? personMask : nil
            )
            if MirrorPhotoLibrary.isEnabled {
                // The copy that leaves the app is flattened, because a photo in
                // someone's camera roll cannot carry a template with it.
                let flattened = MirrorPhotoRenderer.render(
                    photo: image, template: template, payload: payload,
                    analysis: analysis,
                    archive: MirrorArchiveSlice.build(for: template.archiveNeed, endingOn: .now),
                    personMask: personMask
                )
                Task {
                    if await MirrorPhotoLibrary.save(flattened) == false {
                        photosSaveFailed = true
                    }
                }
            }
            // A capture from any door ends the prompt's quiet period and
            // dismissal count: the user is engaged again.
            MirrorMomentManager.shared.recordCaptured()
            MirrorHouseLook.markSeen(template)
            AppAnalytics.shared.trackBlockTap(
                title: "Save mirror photo",
                type: .mirrorPhotoSaved,
                screen: .mirrorCapture,
                metadata: [
                    "filter": template.rawValue,
                    "streak": streak,
                    "has_score": payload.score != nil,
                    "was_suggested": template == suggested
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
               let frame = MirrorPhotoFrame.forStoredDay(days[index]) {
                GeometryReader { proxy in
                    frame
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
