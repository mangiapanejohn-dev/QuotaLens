import AppKit
import SwiftUI
import Combine

/// Owns the menu-bar UI using AppKit primitives. An `NSPopover` hosting the
/// SwiftUI panel becomes a key window when shown, so its controls receive
/// clicks reliably (unlike `MenuBarExtra(.window)`).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: Settings!
    private var store: UsageStore!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let history = HistoryService()
    private var statsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = Settings()
        let store = UsageStore(settings: settings)
        self.settings = settings
        self.store = store
        store.onOpenStats = { [weak self] in self?.openStats() }

        configureStatusItem()
        configurePopover()
        observeAggregate()

        settings.syncLoginItem()
        store.start()
    }

    // MARK: - Statistics window

    private func openStats() {
        popover.performClose(nil)
        if let window = statsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "QuotaLens — Statistics"
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(
            rootView: StatsDashboardView(history: history)
                .environmentObject(store)
                .environmentObject(settings))
        statsWindow = window
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.32
            window.animator().alphaValue = 1
        }
    }

    // MARK: - Status item

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = StatusIcon.image(ratio: store.aggregateRatio, toolName: store.aggregateTool)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover)
        }
        statusItem = item
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)   // consistent dark glass
        let host = NSHostingController(
            rootView: DetailPanelView()
                .environmentObject(store)
                .environmentObject(settings)
        )
        host.sizingOptions = .preferredContentSize   // popover resizes with content
        popover.contentViewController = host
    }

    private func observeAggregate() {
        store.$aggregateRatio
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] ratio in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.statusItem.button?.image = StatusIcon.image(ratio: ratio, toolName: self.store.aggregateTool)
                }
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            store.markOpened()   // replay entrance animations
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
