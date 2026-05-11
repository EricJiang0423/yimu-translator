import AppKit

@MainActor
final class HotkeyManager {
    private var globalMonitor: Any?

    private var selectRegion: (() -> Void)?
    private var toggleRunning: (() -> Void)?
    private var translateNow: (() -> Void)?
    private var toggleOverlay: (() -> Void)?

    func start(
        selectRegion: @escaping () -> Void,
        toggleRunning: @escaping () -> Void,
        translateNow: @escaping () -> Void,
        toggleOverlay: @escaping () -> Void
    ) {
        self.selectRegion = selectRegion
        self.toggleRunning = toggleRunning
        self.translateNow = translateNow
        self.toggleOverlay = toggleOverlay

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                _ = self?.handle(event)
            }
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), flags.contains(.shift),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return false
        }

        let action: (() -> Void)?
        switch key {
        case "s":
            action = selectRegion
        case "t":
            action = toggleRunning
        case "r":
            action = translateNow
        case "h":
            action = toggleOverlay
        default:
            return false
        }
        action?()
        return true
    }
}
