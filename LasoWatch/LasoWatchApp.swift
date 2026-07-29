import SwiftUI

@main
struct LasoWatchApp: App {

    /// Two stores, one per data path. `WatchStore` holds what the phone computed;
    /// `WatchHealthStore` holds what this watch measured. Keeping them apart is what
    /// lets the wrist stay useful when the phone is switched off.
    @State private var store = WatchStore()
    @State private var health = WatchHealthStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: store, health: health)
        }
    }
}
