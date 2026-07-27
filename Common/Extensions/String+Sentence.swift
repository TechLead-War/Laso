import Foundation

extension String {
    /// Lowercases only the first character so a user phrase like "Tired
    /// mornings" reads naturally mid-sentence without touching acronyms later
    /// in the string.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + String(dropFirst())
    }
}

extension Array where Element == String {
    /// Joins names the way a person would say them: "sleep, HRV and strain".
    /// The joiners come from Copy so a translation can change them.
    var sentenceList: String {
        guard count > 1 else { return first ?? "" }
        let head = dropLast().joined(separator: Copy.Home.scoreListJoiner)
        return head + Copy.Home.scoreListFinalJoiner + (last ?? "")
    }
}
