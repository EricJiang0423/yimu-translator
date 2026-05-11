import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private weak var coordinator: TranslationCoordinator?

    init(coordinator: TranslationCoordinator) {
        self.coordinator = coordinator
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let icon = NSImage(contentsOfFile: Bundle.main.path(forResource: "menubar", ofType: "png") ?? "") {
            icon.isTemplate = true   // let the OS tint it for light/dark menu bars
            icon.size = NSSize(width: 18, height: 18)
            statusItem.button?.image = icon
        }
        statusItem.button?.title = ""
        statusItem.button?.toolTip = "译幕"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let coordinator else {
            return
        }

        menu.addItem(NSMenuItem(
            title: coordinator.isRunning ? "Pause 译幕" : "Start 译幕",
            action: #selector(toggleRunning),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "Select Region",
            action: #selector(selectRegion),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "Translate Once",
            action: #selector(translateNow),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "译幕 Settings",
            action: #selector(openSettings),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        menu.items.forEach { $0.target = self }
    }

    @objc private func toggleRunning() {
        coordinator?.toggleRunning()
    }

    @objc private func selectRegion() {
        coordinator?.selectRegion()
    }

    @objc private func translateNow() {
        coordinator?.translateCurrentRegion()
    }

    @objc private func openSettings() {
        coordinator?.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
