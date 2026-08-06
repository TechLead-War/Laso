import ImageIO
import UIKit
import Observation

/// On-device archive of Daily Mirror photos: one finished JPEG per day plus a
/// small meta index, in Application Support/DailyMirror.
///
/// The privacy promise this feature makes in copy is enforced here and only
/// here: every file is written with complete file protection (hardware
/// encryption keyed to the device passcode) and excluded from iCloud and
/// iTunes backups, so the photos exist nowhere but this phone. Nothing in this
/// class touches the network.
@MainActor
@Observable
final class MirrorPhotoStore {

    static let shared = MirrorPhotoStore()

    struct Meta: Codable, Equatable {
        let score: Int?
        /// Capture streak the day this photo was taken, for the streak filter.
        let streak: Int

        /// The overlay this day wears. Nil means the photo predates stored
        /// templates and already has one burned into the pixels, so it must be
        /// shown exactly as it is and never drawn over a second time.
        var template: String?

        /// The day's values, kept so the overlay can be redrawn at view time
        /// and so a past day stays honest: "your last thirty days" on a photo
        /// from March must always mean the thirty days that ended in March.
        var payload: MirrorPayload?

        /// Photos saved before the template moved out of the pixels.
        var isBaked: Bool { template == nil }

        var resolvedTemplate: MirrorTemplate? {
            template.flatMap(MirrorTemplate.init(rawValue:))
        }
    }

    enum StoreError: Error {
        case encodingFailed
    }

    /// Day key ("2026-07-31") to capture meta. Views observe this for refresh.
    private(set) var metaByDay: [String: Meta] = [:]

    private let directory: URL

    /// Longest edge of a gallery thumbnail, in pixels: a 104pt tile on a 3x
    /// screen. NSCache so memory pressure drops them instead of the app.
    private static let thumbnailMaxPixel = 320
    private let thumbnailCache = NSCache<NSString, UIImage>()

    /// Fixed-locale key formatter: the key is a filename, so it must not follow
    /// the device locale's calendar or digits. The time zone is re-read on
    /// every use in `dayKey(for:)`: the app-wide `Date.cal` freezes its zone
    /// at first access, and a key computed in a stale zone would disagree
    /// with the widget's fresh-zone key after the user travels.
    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("DailyMirror", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        excludeFromBackup(directory)
        loadIndex()
    }

    // MARK: - Reads

    static func dayKey(for date: Date) -> String {
        if keyFormatter.timeZone != TimeZone.current {
            keyFormatter.timeZone = TimeZone.current
        }
        return keyFormatter.string(from: Calendar.current.startOfDay(for: date))
    }

    func hasPhoto(on date: Date) -> Bool {
        metaByDay[Self.dayKey(for: date)] != nil
    }

    func meta(on date: Date) -> Meta? {
        metaByDay[Self.dayKey(for: date)]
    }

    func image(on date: Date) -> UIImage? {
        guard hasPhoto(on: date) else { return nil }
        return UIImage(contentsOfFile: photoURL(for: date).path)
    }

    /// Grid-sized decode for the gallery. Loading the full 1440px JPEG for a
    /// 104pt tile costs about 8 MB of decoded pixels each, so a wall of them
    /// would evict itself out of memory while scrolling.
    ///
    /// ponytail: synchronous, cached after first read. A first fast fling
    /// through hundreds of photos does its ImageIO decode on the main thread;
    /// move this to a background queue if that ever shows up as dropped frames.
    func thumbnail(on date: Date) -> UIImage? {
        let key = Self.dayKey(for: date) as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard hasPhoto(on: date),
              let source = CGImageSourceCreateWithURL(photoURL(for: date) as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: Self.thumbnailMaxPixel
              ] as CFDictionary)
        else { return nil }
        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: key)
        return image
    }

    /// The stored JPEG itself, for handing a photo to another framework without
    /// decoding it into memory first.
    func fileURL(on date: Date) -> URL? {
        guard hasPhoto(on: date) else { return nil }
        return photoURL(for: date)
    }

    /// Every day with a photo, oldest first.
    var allDays: [Date] {
        metaByDay.keys
            .compactMap { Self.keyFormatter.date(from: $0) }
            .sorted()
    }

    var photoCount: Int { metaByDay.count }

    var diskBytes: Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return files.reduce(0) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    /// Rest days: missed days the streak walk silently covers, capped per
    /// calendar month. A visible but limited reserve makes people persist more
    /// than rigid rules (Sharif & Shu 2017; Duolingo's streak freeze), and one
    /// missed day genuinely does not break habit formation (Lally et al. 2010).
    static let restDaysPerMonth = 2

    /// Consecutive captured days ending today (or yesterday, so the streak does
    /// not read as broken before tonight's capture happens). Up to
    /// `restDaysPerMonth` missed days per calendar month are covered without
    /// adding to the count, so a single miss keeps the run alive.
    var currentStreak: Int {
        guard let earliest = allDays.first else { return 0 }
        var day = Date.cal.startOfDay(for: .now)
        if !hasPhoto(on: day) {
            day = day.daysAgo(1)
        }
        var streak = 0
        var restUsed: [Int: Int] = [:]
        while day >= earliest {
            if hasPhoto(on: day) {
                streak += 1
            } else {
                let comps = Date.cal.dateComponents([.year, .month], from: day)
                let monthKey = (comps.year ?? 0) * 100 + (comps.month ?? 0)
                guard restUsed[monthKey, default: 0] < Self.restDaysPerMonth else { break }
                restUsed[monthKey, default: 0] += 1
            }
            day = day.daysAgo(1)
        }
        return streak
    }

    /// Captures in the current calendar month. Shown on the prompt after a
    /// streak break instead of a zero, because highlighting a broken streak
    /// measurably reduces persistence (Silverman & Barasch 2023).
    var capturesThisMonth: Int {
        let monthPrefix = String(Self.dayKey(for: .now).prefix(7))
        return metaByDay.keys.filter { $0.hasPrefix(monthPrefix) }.count
    }

    /// Mirrors streak state into the App Group so the home screen widget stays
    /// honest. Called on every archive mutation and on each home open.
    func syncWidgetSnapshot() {
        WidgetDataStore.shared.saveMirror(WidgetMirrorSnapshot(
            streak: currentStreak,
            dayKey: Self.dayKey(for: .now),
            capturedToday: hasPhoto(on: .now),
            updatedAt: .now
        ))
    }

    var longestStreak: Int {
        let days = allDays
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var run = 1
        for (previous, current) in zip(days, days.dropFirst()) {
            run = previous.daysBetween(current) == 1 ? run + 1 : 1
            longest = max(longest, run)
        }
        return longest
    }

    /// First and latest capture, for the share progress pair.
    var progressPair: (firstDay: Date, firstScore: Int?, latestDay: Date, latestScore: Int?)? {
        let days = allDays
        guard let first = days.first, let latest = days.last, first != latest else { return nil }
        return (first, meta(on: first)?.score, latest, meta(on: latest)?.score)
    }

    // MARK: - Writes

    /// Longest photo edge kept on disk. Screens and share cards render at most
    /// story size, so anything larger is wasted space on the user's phone.
    private static let maxPixelDimension: CGFloat = 1440

    /// Writes the plain camera frame plus the choice of overlay.
    ///
    /// The overlay is deliberately NOT drawn into these pixels. Burning it in
    /// made the choice permanent: a template could never be changed after the
    /// fact, a bug in one could never be fixed for a photo already taken, and
    /// no template written later could ever apply to an older day. Keeping the
    /// photo plain and the decision beside it costs a few hundred bytes of
    /// JSON and buys all three back.
    func save(
        _ image: UIImage,
        on date: Date = .now,
        score: Int?,
        streak: Int,
        template: MirrorTemplate,
        payload: MirrorPayload,
        personMask: UIImage? = nil
    ) throws {
        guard let data = Self.downscaled(image).jpegData(compressionQuality: 0.72) else {
            throw StoreError.encodingFailed
        }
        let url = photoURL(for: date)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        excludeFromBackup(url)

        // Only Behind You needs the cutout, so the file is written when there
        // is one and cleared when there is not, rather than left to go stale
        // against a retake that no longer uses it.
        let mask = maskURL(for: date)
        if let personMask, let maskData = personMask.pngData() {
            try? maskData.write(to: mask, options: [.atomic, .completeFileProtection])
            excludeFromBackup(mask)
        } else if FileManager.default.fileExists(atPath: mask.path) {
            try? FileManager.default.removeItem(at: mask)
        }

        // A retake overwrites the day's file, so a stale thumbnail would keep
        // showing the photo the user just replaced.
        thumbnailCache.removeObject(forKey: Self.dayKey(for: date) as NSString)
        metaByDay[Self.dayKey(for: date)] = Meta(
            score: score, streak: streak, template: template.rawValue, payload: payload
        )
        try persistIndex()
        syncWidgetSnapshot()
    }

    func personMask(on date: Date) -> UIImage? {
        let url = maskURL(for: date)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func delete(on date: Date) throws {
        let url = photoURL(for: date)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        // The cutout is part of the photo, so it goes with it. Leaving it
        // behind would keep a recognisable silhouette of a deleted day on disk.
        let mask = maskURL(for: date)
        if FileManager.default.fileExists(atPath: mask.path) {
            try? FileManager.default.removeItem(at: mask)
        }
        thumbnailCache.removeObject(forKey: Self.dayKey(for: date) as NSString)
        metaByDay[Self.dayKey(for: date)] = nil
        try persistIndex()
        syncWidgetSnapshot()
    }

    func deleteAll() throws {
        for date in allDays {
            for url in [photoURL(for: date), maskURL(for: date)]
            where FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        thumbnailCache.removeAllObjects()
        metaByDay = [:]
        try persistIndex()
        syncWidgetSnapshot()
    }

    // MARK: - Private

    private func photoURL(for date: Date) -> URL {
        directory.appendingPathComponent("\(Self.dayKey(for: date)).jpg")
    }

    private func maskURL(for date: Date) -> URL {
        directory.appendingPathComponent("\(Self.dayKey(for: date)).mask.png")
    }

    private var indexURL: URL {
        directory.appendingPathComponent("index.json")
    }

    private func loadIndex() {
        if let data = try? Data(contentsOf: indexURL),
           let decoded = try? JSONDecoder().decode([String: Meta].self, from: data) {
            metaByDay = decoded
        }
        // Photos on disk are the source of truth: a photo whose index entry was
        // lost still shows up rather than silently disappearing.
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "jpg" {
            let key = file.deletingPathExtension().lastPathComponent
            if metaByDay[key] == nil {
                metaByDay[key] = Meta(score: nil, streak: 0)
            }
        }
    }

    private func persistIndex() throws {
        let data = try JSONEncoder().encode(metaByDay)
        try data.write(to: indexURL, options: [.atomic, .completeFileProtection])
        excludeFromBackup(indexURL)
    }

    private func excludeFromBackup(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height) * image.scale
        guard longest > maxPixelDimension else { return image }
        let ratio = maxPixelDimension / longest
        let size = CGSize(width: image.size.width * image.scale * ratio,
                          height: image.size.height * image.scale * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
