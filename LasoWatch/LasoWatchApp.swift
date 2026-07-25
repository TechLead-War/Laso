import SwiftUI

@main
struct LasoWatchApp: App {

    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: store)
        }
    }
}
