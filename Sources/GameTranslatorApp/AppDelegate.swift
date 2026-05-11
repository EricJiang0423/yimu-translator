import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: TranslationCoordinator?
    private var statusBarController: StatusBarController?
    private var hotkeyManager: HotkeyManager?
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configurationStore = ConfigurationStore()
        let overlay = TranslationOverlayWindow()
        let coordinator = TranslationCoordinator(
            configurationStore: configurationStore,
            captureService: ScreenCaptureService(),
            ocrService: VisionOCRService(),
            overlayWindow: overlay
        )
        self.coordinator = coordinator

        let statusBarController = StatusBarController(coordinator: coordinator)
        self.statusBarController = statusBarController

        let mainWindowController = MainWindowController(
            configurationStore: configurationStore,
            coordinator: coordinator
        )
        self.mainWindowController = mainWindowController
        coordinator.attachMainWindow(mainWindowController)
        coordinator.onStatusChange = { [weak mainWindowController] message in
            mainWindowController?.setStatus(message)
        }
        coordinator.onTranslation = { [weak mainWindowController] original, translated in
            mainWindowController?.appendLog(original: original, translated: translated)
        }
        mainWindowController.showWindow(nil)
        mainWindowController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        let hotkeyManager = HotkeyManager()
        hotkeyManager.start(
            selectRegion: { [weak coordinator] in coordinator?.selectRegion() },
            toggleRunning: { [weak coordinator] in coordinator?.toggleRunning() },
            translateNow: { [weak coordinator] in coordinator?.translateCurrentRegion() },
            toggleOverlay: { [weak overlay] in overlay?.toggleVisibility() }
        )
        self.hotkeyManager = hotkeyManager

        // Request capture access at a predictable time. No preflight check —
        // CGPreflightScreenCaptureAccess() is unreliable for unsigned apps on
        // Sequoia. ScreenCaptureKit will prompt if needed when capture starts.
        ScreenCaptureService.requestAccessIfNeeded()
        PermissionAlert.showScreenCaptureHint()
    }
}

enum PermissionAlert {
    @MainActor
    static func showScreenCaptureHint() {
        let alert = NSAlert()
        alert.messageText = "屏幕录制权限"
        alert.informativeText = "译幕 需要通过屏幕录制来截取游戏台词。如果系统弹出了权限对话框，请点「允许」。\n\n如果点了「不允许」或没看到弹窗，请到「系统设置 → 隐私与安全性 → 屏幕录制」中勾选「译幕」，然后完全退出 App（⌘Q）再重新打开。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
