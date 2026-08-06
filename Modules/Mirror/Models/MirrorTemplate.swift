import SwiftUI

/// The overlays a Daily Mirror photo can wear.
///
/// A template is chosen at capture and stored beside the photo rather than
/// burned into it, so the choice stays changeable and a template written later
/// still applies to a photo taken today.
enum MirrorTemplate: String, CaseIterable, Identifiable, Codable {

    // Everyday
    case fieldNotes, number, oneWord, clean
    // Depth and data
    case behindYou, horizon, night, bodyAge
    // Physical objects
    case slip, chin, newsprint, nineties
    // The archive
    case thisWeek, thenAndNow, contactSheet
    // Voice
    case sentence, claim, landmark

    var id: String { rawValue }

    var label: String { Copy.Mirror.templateName(self) }

    var group: Group {
        switch self {
        case .fieldNotes, .number, .oneWord, .clean:        return .everyday
        case .behindYou, .horizon, .night, .bodyAge:        return .data
        case .slip, .chin, .newsprint, .nineties:           return .object
        case .thisWeek, .thenAndNow, .contactSheet:         return .archive
        case .sentence, .claim, .landmark:                  return .voice
        }
    }

    enum Group: String, CaseIterable, Identifiable {
        case everyday, data, object, archive, voice
        var id: String { rawValue }
        var label: String { Copy.Mirror.templateGroup(self) }
    }

    /// What each one needs before it can draw anything worth looking at.
    /// A template that cannot meet its requirement is never offered, which is
    /// how the picker avoids ever showing an empty frame.
    func isAvailable(payload: MirrorPayload, archive: ArchiveFacts) -> Bool {
        switch self {
        case .clean, .oneWord, .fieldNotes:
            return true
        case .number, .behindYou:
            return payload.hasScore
        case .horizon:
            return payload.hasHistory
        case .night:
            return payload.hasStages
        case .bodyAge:
            return payload.hasAges
        case .slip:
            // The slip is a list, and a list of one line is not a receipt.
            return payload.hasScore || payload.hasSleep
        case .chin:
            return payload.actionLine != nil || payload.sentence != nil || payload.hasScore
        case .newsprint, .nineties:
            return payload.hasScore
        case .thisWeek:
            return archive.recentDays >= 3
        case .thenAndNow:
            return archive.hasPair
        case .contactSheet:
            return archive.totalDays >= 9
        case .sentence:
            return payload.sentence != nil
        case .claim:
            return payload.hasHistory
        case .landmark:
            return archive.landmark != nil
        }
    }

    /// The archive side of availability, passed in so a template never reaches
    /// into the store on its own and the picker can be previewed in isolation.
    struct ArchiveFacts: Equatable {
        var totalDays: Int
        /// Captured days inside the last seven.
        var recentDays: Int
        var hasPair: Bool
        /// The number worth a full screen today, if this is one of those days.
        var landmark: Int?

        static let none = ArchiveFacts(totalDays: 0, recentDays: 0, hasPair: false, landmark: nil)

        /// Only these get a plate of their own. Celebrating every day is the
        /// same as celebrating none of them.
        static let landmarks: Set<Int> = [7, 30, 100, 365, 500, 1000]

        @MainActor
        static func from(store: MirrorPhotoStore, streak: Int, on date: Date = .now) -> ArchiveFacts {
            let recent = (0..<7).reduce(into: 0) { total, offset in
                if store.hasPhoto(on: date.daysAgo(offset)) { total += 1 }
            }
            return ArchiveFacts(
                totalDays: store.photoCount,
                recentDays: recent,
                hasPair: store.progressPair != nil,
                landmark: landmarks.contains(streak) ? streak : nil
            )
        }
    }

    static func available(payload: MirrorPayload, archive: ArchiveFacts) -> [MirrorTemplate] {
        allCases.filter { $0.isAvailable(payload: payload, archive: archive) }
    }

    /// The template the day itself asks for, checked in order. A landmark beats
    /// everything, a hard day is answered with a word rather than a red number,
    /// and a seventh capture shows the week it completed.
    static func suggested(
        payload: MirrorPayload,
        archive: ArchiveFacts,
        houseLook: MirrorTemplate,
        lighting: MirrorLegibility.Difficulty
    ) -> MirrorTemplate {
        let options = available(payload: payload, archive: archive)
        func pick(_ candidate: MirrorTemplate) -> MirrorTemplate? {
            options.contains(candidate) ? candidate : nil
        }

        if archive.landmark != nil, let hit = pick(.landmark) { return hit }
        if let score = payload.score, score < DS.fairFloor, let hit = pick(.oneWord) { return hit }
        if let debt = payload.debtHours, debt >= 5, let hit = pick(.oneWord) { return hit }
        if archive.recentDays >= 6, let hit = pick(.thisWeek) { return hit }
        // A frame the engine cannot protect with a gradient gets the template
        // whose contrast does not depend on the photo at all.
        if lighting == .hostile, let hit = pick(.slip) { return hit }
        return pick(houseLook) ?? options.first ?? .clean
    }

    /// Why the suggestion was made, shown under it so the pick never feels random.
    static func suggestionReason(
        payload: MirrorPayload,
        archive: ArchiveFacts,
        lighting: MirrorLegibility.Difficulty,
        picked: MirrorTemplate
    ) -> String? {
        switch picked {
        case .landmark:  return archive.landmark.map { Copy.Mirror.suggestLandmark($0) }
        case .oneWord:   return Copy.Mirror.suggestQuiet
        case .thisWeek:  return Copy.Mirror.suggestWeek
        case .slip where lighting == .hostile: return Copy.Mirror.suggestLighting
        default:         return nil
        }
    }
}

// MARK: - Persisted preferences

/// The look picked once during the first capture and applied to every one
/// after. A tray at every capture is a daily decision, and daily decisions are
/// where people drop out.
@MainActor
enum MirrorHouseLook {
    static var current: MirrorTemplate {
        get {
            let raw = UserDefaults.standard.string(forKey: AppKeys.Mirror.houseLook) ?? ""
            return MirrorTemplate(rawValue: raw) ?? .fieldNotes
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: AppKeys.Mirror.houseLook) }
    }

    /// Templates the user has not used yet, so the picker can mark them once
    /// and then stop.
    static func isUnseen(_ template: MirrorTemplate) -> Bool {
        !seen.contains(template.rawValue)
    }

    static func markSeen(_ template: MirrorTemplate) {
        guard !seen.contains(template.rawValue) else { return }
        UserDefaults.standard.set(Array(seen) + [template.rawValue], forKey: AppKeys.Mirror.seenTemplates)
    }

    private static var seen: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: AppKeys.Mirror.seenTemplates) ?? [])
    }
}
