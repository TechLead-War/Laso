import SwiftUI

/// The whole Daily Mirror archive as one scrollable wall, newest month first.
/// Tapping a day opens it full screen, where the archive pages side to side.
struct MirrorGalleryView: View {

    private struct Day: Identifiable, Hashable {
        let id: String
        let date: Date
    }

    private struct Month: Identifiable {
        let id: String
        let title: String
        let days: [Day]
    }

    private let store = MirrorPhotoStore.shared
    @State private var viewerDay: Day?
    @State private var showShare = false

    /// Adaptive so the wall is four across on a Pro Max and three on an SE,
    /// instead of a fixed count that leaves a gutter on one of them.
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: DS.space2)]

    var body: some View {
        ScrollView {
            if months.isEmpty {
                Text(Copy.Mirror.settingsEmpty)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.space6)
                    .padding(.top, DS.space8)
            } else {
                LazyVStack(alignment: .leading, spacing: DS.space5, pinnedViews: [.sectionHeaders]) {
                    ForEach(months) { month in
                        Section {
                            LazyVGrid(columns: columns, spacing: DS.space2) {
                                ForEach(month.days) { day in
                                    Button { open(day) } label: { tile(day) }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                }
                            }
                        } header: {
                            Text(month.title)
                                .font(DS.Typography.subheadlineSemibold)
                                .foregroundStyle(AppColour.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, DS.space2)
                                .background(AppColour.surfaceBase)
                        }
                    }
                }
                .padding(.horizontal, DS.space4)
                .padding(.bottom, DS.space6)
            }
        }
        .background(AppColour.surfaceBase)
        .navigationTitle(Copy.Mirror.galleryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The then-vs-now pair is the one card this screen is about, so the
            // tray here is built from the archive alone rather than reaching for
            // the dashboard's scorers, which this view has no access to.
            if !mirrorTemplates.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showShare = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(Copy.Common.shareHealthCard)
                    .accessibilityIdentifier("share.entry")
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareWinSheet(templates: mirrorTemplates)
        }
        .onAppear { AppAnalytics.shared.trackFeatureOpen(.mirrorGallery) }
        .onDisappear { AppAnalytics.shared.trackFeatureClose(.mirrorGallery) }
        .fullScreenCover(item: $viewerDay) { day in
            MirrorGalleryViewer(start: day.date) { viewerDay = nil }
        }
    }

    /// Empty until two photos sit far enough apart to read as progress, which
    /// is the builder's own gate rather than a second one kept here.
    private var mirrorTemplates: [ShareTemplate] {
        ShareTemplateBuilder.build(
            vitalityAge: nil, realAge: nil, recovery: nil, masterStreak: 0,
            actionResult: nil, lastNightSleepSeconds: nil, allTimeBestSleepHours: nil,
            mirrorPair: store.progressPair
        )
    }

    /// Newest month first, days newest first inside it. Grouped by the stored
    /// day key rather than by calendar maths, so the sections always line up
    /// with the filenames the archive is keyed on.
    private var months: [Month] {
        var order: [String] = []
        var buckets: [String: [Day]] = [:]
        for date in store.allDays.reversed() {
            let day = Day(id: MirrorPhotoStore.dayKey(for: date), date: date)
            let key = String(day.id.prefix(7))
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(day)
        }
        return order.compactMap { key in
            guard let days = buckets[key], let first = days.first else { return nil }
            return Month(id: key, title: first.date.formatted(.dateTime.month(.wide).year()), days: days)
        }
    }

    private func tile(_ day: Day) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumbnail = store.thumbnail(on: day.date) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    AppColour.surfaceRaised
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(alignment: .bottomLeading) {
                // Day number only: the month is already the section header, and
                // a full date does not fit a 100pt tile.
                Text(day.date.formatted(.dateTime.day()))
                    .font(DS.Typography.captionSemibold)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
                    .padding(DS.space2)
            }
    }

    private func open(_ day: Day) {
        AppAnalytics.shared.trackBlockTap(
            title: "Mirror gallery photo",
            type: .mirrorPhotoOpened,
            screen: .mirrorGallery
        )
        viewerDay = day
    }
}

/// One photo full screen, with the rest of the archive a swipe away. Newest on
/// the left, matching the order of the wall it was opened from.
private struct MirrorGalleryViewer: View {

    let onClose: () -> Void

    @State private var selection: Date
    @State private var confirmDelete = false
    @State private var deleteFailed = false

    private let store = MirrorPhotoStore.shared

    init(start: Date, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _selection = State(initialValue: start)
    }

    /// Read from the store on every render rather than snapshotted at open, so
    /// deleting a photo from here drops its page immediately.
    private var days: [Date] { store.allDays.reversed() }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(days, id: \.self) { day in
                    Group {
                        if let image = store.image(on: day) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Color.black
                        }
                    }
                    .tag(day)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { deleteButton }
        .confirmationDialog(
            Copy.Mirror.galleryDeleteConfirm,
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button(Copy.Mirror.galleryDelete, role: .destructive) { delete() }
            Button(Copy.Buttons.cancel, role: .cancel) {}
        }
        .alert(Copy.Mirror.saveFailed, isPresented: $deleteFailed) {
            Button(Copy.Buttons.done, role: .cancel) {}
        }
    }

    private var topBar: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selection.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(DS.Typography.title3)
                    .foregroundStyle(.white)
                if let score = store.meta(on: selection)?.score {
                    Text(Copy.Mirror.recoveryScore(score))
                        .font(DS.Typography.captionSemibold)
                        .foregroundStyle(DS.scoreColor(score))
                }
            }
            Spacer()
            Button(Copy.Explore.dayClose) { onClose() }
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(.white)
                .padding(.horizontal, DS.space4)
                .padding(.vertical, DS.space2)
                .background(.white.opacity(0.15), in: Capsule())
        }
        .padding(DS.space4)
        .background(.black.opacity(0.35))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Image(systemName: "trash")
                .font(DS.Typography.subheadlineSemibold)
                .foregroundStyle(.white)
                .padding(DS.space3)
                .background(.black.opacity(0.55), in: Circle())
        }
        .accessibilityLabel(Copy.Mirror.galleryDelete)
        .padding(.bottom, DS.space6)
    }

    private func delete() {
        guard let index = days.firstIndex(of: selection) else { return }
        do {
            try store.delete(on: selection)
        } catch {
            deleteFailed = true
            return
        }
        AppAnalytics.shared.trackBlockTap(
            title: "Delete mirror photo",
            type: .mirrorArchiveDeleted,
            screen: .mirrorGallery,
            metadata: ["scope": "single"]
        )
        let remaining = days
        guard !remaining.isEmpty else {
            onClose()
            return
        }
        // The page that took the deleted one's place, or the new last photo.
        selection = remaining[min(index, remaining.count - 1)]
    }
}
