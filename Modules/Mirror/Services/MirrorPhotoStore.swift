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
    }

    enum StoreError: Error {
        case encodingFailed
    }

    /// Day key ("2026-07-31") to capture meta. Views observe this for refresh.
    private(set) var metaByDay: [String: Meta] = [:]

    private let directory: URL

    /// Fixed-locale key formatter: the key is a filename, so it must not follow
    /// the device locale's calendar or digits.
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
        keyFormatter.string(from: Date.cal.startOfDay(for: date))
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

    /// Consecutive captured days ending today (or yesterday, so the streak does
    /// not read as broken before tonight's capture happens).
    var currentStreak: Int {
        var day = Date.cal.startOfDay(for: .now)
        if !hasPhoto(on: day) {
            day = day.daysAgo(1)
        }
        var streak = 0
        while hasPhoto(on: day) {
            streak += 1
            day = day.daysAgo(1)
        }
        return streak
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

    func save(_ image: UIImage, on date: Date = .now, score: Int?, streak: Int) throws {
        guard let data = Self.downscaled(image).jpegData(compressionQuality: 0.72) else {
            throw StoreError.encodingFailed
        }
        let url = photoURL(for: date)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        excludeFromBackup(url)

        metaByDay[Self.dayKey(for: date)] = Meta(score: score, streak: streak)
        try persistIndex()
    }

    func delete(on date: Date) throws {
        let url = photoURL(for: date)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        metaByDay[Self.dayKey(for: date)] = nil
        try persistIndex()
    }

    func deleteAll() throws {
        for date in allDays {
            let url = photoURL(for: date)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
        metaByDay = [:]
        try persistIndex()
    }

    // MARK: - Private

    private func photoURL(for date: Date) -> URL {
        directory.appendingPathComponent("\(Self.dayKey(for: date)).jpg")
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
