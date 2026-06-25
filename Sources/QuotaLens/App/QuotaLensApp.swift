import SwiftUI

@main
struct QuotaLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu bar UI is driven entirely by AppDelegate via NSStatusItem +
        // NSPopover (reliable click handling). This invisible scene just gives
        // the SwiftUI App a valid, window-less lifecycle for an accessory app.
        SwiftUI.Settings { EmptyView() }
    }
}
