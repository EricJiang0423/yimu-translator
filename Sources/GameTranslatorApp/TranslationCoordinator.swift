import AppKit
import CoreGraphics
import GameTranslatorCore

@MainActor
final class TranslationCoordinator {
    private let configurationStore: ConfigurationStore
    private let captureService: ScreenCaptureService
    private let ocrService: VisionOCRService
    private let overlayWindow: TranslationOverlayWindow
    private let cache = TranslationCache()

    private var selectedRegion: CGRect?
    private var detector = FrameChangeDetector()
    private var timer: Timer?
    private var isProcessing = false
    private var lastRecognizedText = ""
    private var lastTranslatedText = ""
    private var selectionController: RegionSelectionController?
    private weak var mainWindowController: MainWindowController?

    private(set) var isRunning = false
    var onStatusChange: ((String) -> Void)?
    var onTranslation: ((_ original: String, _ translated: String) -> Void)?
    var hasSelectedRegion: Bool {
        selectedRegion != nil
    }

    init(
        configurationStore: ConfigurationStore,
        captureService: ScreenCaptureService,
        ocrService: VisionOCRService,
        overlayWindow: TranslationOverlayWindow
    ) {
        self.configurationStore = configurationStore
        self.captureService = captureService
        self.ocrService = ocrService
        self.overlayWindow = overlayWindow
    }

    func selectRegion() {
        guard selectionController == nil else {
            onStatusChange?("Region selection is already open. Drag over the text area.")
            return
        }
        onStatusChange?("Drag over the text area, then release.")
        let selector = RegionSelectionController()
        selectionController = selector
        selector.begin { [weak self] region in
            guard let self else { return }
            self.selectionController = nil
            guard let region else {
                self.isRunning = false
                self.restartTimer()
                self.onStatusChange?("Region selection cancelled.")
                return
            }
            self.selectedRegion = region
            self.detector.reset()
            self.lastRecognizedText = ""
            self.lastTranslatedText = ""
            self.onStatusChange?("Region selected. Translating once...")
            self.start()
            self.translateCurrentRegion()
        }
    }

    func toggleRunning() {
        isRunning ? pause() : start()
    }

    func start() {
        guard selectedRegion != nil else {
            isRunning = false
            onStatusChange?("No region selected. Select the game text area first.")
            selectRegion()
            return
        }
        isRunning = true
        restartTimer()
        onStatusChange?("Running. Watching the selected region.")
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        overlayWindow.hide()
        onStatusChange?("Paused.")
    }

    func translateCurrentRegion() {
        guard let selectedRegion else {
            selectRegion()
            return
        }
        process(region: selectedRegion, force: true)
    }

    func toggleOverlayVisibility() {
        overlayWindow.toggleVisibility()
        onStatusChange?("译幕 overlay visibility toggled.")
    }

    func testCurrentProvider() async throws -> String {
        let configuration = configurationStore.configuration
        let provider = try Self.makeProvider(configuration: configuration)
        let translated = try await provider.translate(TranslationRequest(
            text: TranslationSample.text(for: configuration.sourceLanguage),
            sourceLanguage: configuration.sourceLanguage,
            targetLanguage: configuration.targetLanguage
        ))
        return translated.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func runSelfTest(anchor: CGRect?) async -> String {
        let configuration = configurationStore.configuration
        let targetRegion = anchor
            ?? mainWindowController?.window?.frame
            ?? CGRect(x: 240, y: 240, width: 460, height: 120)
        let screenAccess = ScreenCaptureService.hasScreenCaptureAccess
        let permissionLine = screenAccess
            ? "屏幕录制权限：已授予 ✓"
            : "屏幕录制权限：未开启。截取区域会失败，请在设置中启用后重启 App。"

        overlayWindow.show(
            text: "译幕 overlay is visible.\n\(permissionLine)",
            near: targetRegion,
            configuration: configuration,
            forceVisible: true
        )

        do {
            let translated = try await testCurrentProvider()
            overlayWindow.show(
                text: "Tencent API OK:\n\(translated)",
                near: targetRegion,
                configuration: configuration,
                forceVisible: true
            )
            return "译幕 self test passed. \(permissionLine)"
        } catch {
            overlayWindow.show(
                text: "Overlay OK.\nTencent API failed: \(error.localizedDescription)",
                near: targetRegion,
                configuration: configuration,
                forceVisible: true
            )
            return "Overlay test passed. Tencent API failed: \(error.localizedDescription). \(permissionLine)"
        }
    }

    func openSettings() {
        mainWindowController?.showWindow(nil)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func attachMainWindow(_ mainWindowController: MainWindowController) {
        self.mainWindowController = mainWindowController
    }

    func reloadConfiguration() {
        if isRunning {
            restartTimer()
        }
        if let selectedRegion, !lastTranslatedText.isEmpty {
            overlayWindow.show(
                text: lastTranslatedText,
                near: selectedRegion,
                configuration: configurationStore.configuration
            )
        }
    }

    private func restartTimer() {
        timer?.invalidate()
        guard isRunning else {
            return
        }
        let interval = configurationStore.configuration.clampedPollingInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func poll() {
        guard isRunning, let selectedRegion else {
            return
        }
        process(region: selectedRegion, force: false)
    }

    private func process(region: CGRect, force: Bool) {
        guard !isProcessing else {
            return
        }
        isProcessing = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer {
                self.isProcessing = false
            }

            do {
                let image = try await captureService.capture(region: region)
                let fingerprint = captureService.fingerprint(for: image)
                let changed = detector.shouldProcess(fingerprint: fingerprint)
                if !force, !changed {
                    return
                }

                let text = try await ocrService.recognizeText(
                    in: image,
                    sourceLanguage: configurationStore.configuration.sourceLanguage
                )
                guard !text.isEmpty else {
                    onStatusChange?("OCR returned empty text. The region may not contain recognizable text.")
                    return
                }
                guard TextNormalizer.containsRecognizableText(text) else {
                    onStatusChange?("OCR found text but no recognizable characters. Raw: \(text.prefix(60))")
                    return
                }

                let shouldSkip: Bool = {
                    if !force, lastRecognizedText == text {
                        return true
                    }
                    lastRecognizedText = text
                    return false
                }()
                if shouldSkip {
                    return
                }

                let configuration = configurationStore.configuration
                let provider = try Self.makeProvider(configuration: configuration)
                let key = TranslationCacheKey(
                    originalText: text,
                    targetLanguage: configuration.targetLanguage,
                    providerID: provider.id
                )
                let translated: String
                if let cached = cache.value(for: key) {
                    translated = cached
                } else {
                    translated = try await provider.translate(TranslationRequest(
                        text: text,
                        sourceLanguage: configuration.sourceLanguage,
                        targetLanguage: configuration.targetLanguage
                    ))
                    cache.insert(translated, for: key)
                }

                lastTranslatedText = translated
                overlayWindow.show(text: translated, near: region, configuration: configuration, forceVisible: force)
                onTranslation?(text, translated)
                onStatusChange?("Translated \(text.count) characters with Tencent TMT.")
            } catch is ScreenCaptureError {
                // Permission error → pause polling to avoid spamming the user.
                // User must restart after granting screen recording access.
                pause()
                onStatusChange?("屏幕录制权限未开启，已暂停轮询。请在「系统设置 → 隐私与安全性 → 屏幕录制」中勾选「译幕」，然后完全退出后重新打开。")
                overlayWindow.showError("屏幕录制权限未开启，已暂停轮询。\n请到系统设置 → 隐私 → 屏幕录制中勾选「译幕」，\n然后完全退出 App 再重新打开。", near: region, configuration: configurationStore.configuration)
            } catch {
                overlayWindow.showError(error.localizedDescription, near: region, configuration: configurationStore.configuration)
                onStatusChange?("Translation failed: \(error.localizedDescription)")
            }
        }
    }

    private static func makeProvider(configuration: AppConfiguration) throws -> any TranslationProvider {
        try TencentTMTTranslationProvider(
            secretID: configuration.credentialID,
            secretKey: configuration.apiSecret,
            region: configuration.tencentRegion
        )
    }
}

private enum TranslationSample {
    static func text(for sourceLanguage: String) -> String {
        switch sourceLanguage {
        case "Chinese (Simplified)":
            return "欢迎回来，勇者。新的冒险正在等你。"
        case "Chinese (Traditional)":
            return "歡迎回來，勇者。新的冒險正在等你。"
        case "Korean":
            return "돌아온 걸 환영해, 용사님. 새로운 모험이 기다리고 있어요."
        case "English":
            return "Welcome back, adventurer. A new quest is waiting."
        case "French":
            return "Bon retour, aventurier. Une nouvelle quete vous attend."
        case "German":
            return "Willkommen zuruck, Abenteurer. Eine neue Aufgabe wartet."
        case "Spanish":
            return "Bienvenido de nuevo, aventurero. Te espera una nueva mision."
        case "Italian":
            return "Bentornato, avventuriero. Ti aspetta una nuova missione."
        case "Portuguese":
            return "Bem-vindo de volta, aventureiro. Uma nova missao espera por voce."
        case "Thai":
            return "ยินดีต้อนรับกลับมา นักผจญภัย ภารกิจใหม่กำลังรอคุณอยู่"
        case "Vietnamese":
            return "Chao mung tro lai, nha phieu luu. Mot nhiem vu moi dang cho ban."
        default:
            return "おかえりなさい、勇者様。新しい冒険が待っています。"
        }
    }
}
