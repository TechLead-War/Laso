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
