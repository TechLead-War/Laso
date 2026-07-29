import WatchKit

/// Every state change on the wrist is confirmed by feel.
///
/// The shipping app fired no haptics at all, and its two "saved" strings were dead code
/// no view ever showed, so a tap that reached the phone looked identical to one that did
/// not.
enum WatchHaptics {

    /// A write the phone accepted, or a value the wearer just changed.
    static func success() { play(.success) }

    /// A write the phone refused. Never silent: a rejected write that looks saved is
    /// worse than one that visibly failed.
    static func failure() { play(.failure) }

    /// A constraint to remember before building a deliberate measurement screen:
    ///
    /// "When you engage the haptic engine, HealthKit stops gathering heart rate data
    /// until after the haptic engine finishes."
    /// https://developer.apple.com/documentation/watchkit/wkinterfacedevice/play(_:)
    ///
    /// It is not guarded here because nothing in this app takes a timed reading. The
    /// background stream loses at most one sample to a tap the wearer made themselves,
    /// which no screen reports. A guard would have to be armed by that measurement
    /// screen; an always-off flag would only look like protection.
    private static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
