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

        if !ScreenCaptureService.hasScreenCaptureAccess {
            try? ScreenCaptureService.ensureCaptureAccess()
            PermissionAlert.showScreenCaptureHint()
        }
    }
}

enum PermissionAlert {
    @MainActor
    static func showScreenCaptureHint() {
        let alert = NSAlert()
        alert.messageText = "需要屏幕录制权限"
        alert.informativeText = "译幕 需要通过屏幕录制来截取游戏台词区域。\n\n请在「系统设置 → 隐私与安全性 → 屏幕录制」中勾选「译幕」，然后完全退出 App（⌘Q）再重新打开，权限才会生效。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
}
