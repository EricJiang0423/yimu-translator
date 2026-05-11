import AppKit
import GameTranslatorCore

/// Top-origin coordinate view so NSScrollView document content grows downward.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class MainWindowController: NSWindowController {
    private let configurationStore: ConfigurationStore
    private weak var coordinator: TranslationCoordinator?

    // MARK: Palette (Midnight Glass)

    private static let accent = NSColor(calibratedRed: 0.30, green: 0.62, blue: 1.00, alpha: 1)
    private static let cardFill = NSColor.white.withAlphaComponent(0.045)
    private static let cardStroke = NSColor.white.withAlphaComponent(0.085)
    private static let hairline = NSColor.white.withAlphaComponent(0.10)

    // MARK: Settings controls

    private let sourceLanguagePopup = NSPopUpButton()
    private let targetLanguageField = NSTextField()
    private let secretIDField = NSTextField()
    private let secretKeyField = NSSecureTextField()
    private let regionPopup = NSPopUpButton()
    private let pollingIntervalField = NSTextField()
    private let fontSizeField = NSTextField()
    private let opacitySlider = NSSlider(value: 0.72, minValue: 0.25, maxValue: 1.0, target: nil, action: nil)

    // MARK: Action controls

    private let startButton = NSButton(title: "开始", target: nil, action: nil)
    private let testAPIButton = NSButton(title: "测试 API", target: nil, action: nil)
    private let selfTestButton = NSButton(title: "自检", target: nil, action: nil)
    private let statusDot = NSView()
    private let statusLabel = NSTextField(labelWithString: "未运行")

    // MARK: Log

    private let logStack = NSStackView()
    private let logScroll = NSScrollView()
    private let logPlaceholder = NSTextField(labelWithString: "翻译结果会出现在这里")
    private let logCountLabel = NSTextField(labelWithString: "")
    private var logEntries: [(original: String, translated: String)] = []
    private let maxLogEntries = 50

    private static let supportedSourceLanguages = [
        "Japanese", "Chinese (Simplified)", "Chinese (Traditional)",
        "Korean", "English", "French", "German",
        "Spanish", "Italian", "Portuguese", "Thai", "Vietnamese"
    ]
    private static let tencentRegions = [
        "ap-guangzhou", "ap-shanghai", "ap-beijing", "ap-hongkong"
    ]

    // MARK: - Init

    init(configurationStore: ConfigurationStore, coordinator: TranslationCoordinator) {
        self.configurationStore = configurationStore
        self.coordinator = coordinator

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 940, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "译幕"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = CGSize(width: 820, height: 500)
        window.appearance = NSAppearance(named: .darkAqua)
        window.center()
        super.init(window: window)

        window.contentView = makeContentView()
        loadConfiguration()
        updateRunningState()
        updateLogChrome()
    }

    required init?(coder: NSCoder) { nil }

    // MARK: - Public API

    func refresh() { loadConfiguration(); updateRunningState() }

    func setStatus(_ message: String) {
        statusLabel.stringValue = message.isEmpty ? (coordinator?.isRunning == true ? "运行中" : "未运行") : message
    }

    func appendLog(original: String, translated: String) {
        logEntries.insert((original, translated), at: 0)
        if logEntries.count > maxLogEntries { logEntries.removeLast() }
        rebuildLog()
    }

    // MARK: - Root layout

    private func makeContentView() -> NSView {
        let blur = NSVisualEffectView()
        blur.material = .underWindowBackground
        blur.blendingMode = .behindWindow
        blur.state = .active

        let columns = NSStackView()
        columns.orientation = .horizontal
        columns.spacing = 0
        columns.distribution = .fill
        columns.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(columns)

        let left = makeLeftColumn()
        left.widthAnchor.constraint(equalToConstant: 384).isActive = true

        let divider = NSBox()
        divider.boxType = .custom
        divider.fillColor = Self.hairline
        divider.borderWidth = 0
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true

        let right = makeRightColumn()

        columns.addArrangedSubview(left)
        columns.addArrangedSubview(divider)
        columns.addArrangedSubview(right)

        NSLayoutConstraint.activate([
            columns.topAnchor.constraint(equalTo: blur.topAnchor),
            columns.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            columns.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            columns.bottomAnchor.constraint(equalTo: blur.bottomAnchor)
        ])
        return blur
    }

    // Standard inset so content clears the transparent title bar.
    private let titleBarInset: CGFloat = 30

    // MARK: - Left column (settings)

    private func makeLeftColumn() -> NSView {
        let container = NSView()

        let title = NSTextField(labelWithString: "译幕")
        title.font = .systemFont(ofSize: 15, weight: .semibold)
        title.textColor = .labelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)

        let subtitle = NSTextField(labelWithString: "框住台词，即刻入戏")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .tertiaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitle)

        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.scrollerStyle = .overlay
        container.addSubview(scroll)

        let doc = FlippedView()
        doc.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = doc

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 20
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 20, bottom: 24, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)

        sourceLanguagePopup.addItems(withTitles: Self.supportedSourceLanguages)
        regionPopup.addItems(withTitles: Self.tencentRegions)
        [secretIDField, secretKeyField, targetLanguageField, pollingIntervalField, fontSizeField].forEach(styleField)

        stack.addArrangedSubview(card(title: "腾讯云 TMT", rows: [
            row("SecretId", secretIDField),
            row("SecretKey", secretKeyField),
            row("Region", regionPopup)
        ]))
        stack.addArrangedSubview(card(title: "识别", rows: [
            row("源语言", sourceLanguagePopup),
            row("目标", targetLanguageField),
            row("轮询", pollingIntervalField, suffix: "秒  ·  0.2–3.0")
        ]))
        stack.addArrangedSubview(card(title: "浮层", rows: [
            row("字号", fontSizeField, suffix: "pt  ·  12–36"),
            row("透明度", opacitySlider)
        ]))
        stack.addArrangedSubview(makeActionBlock())

        let hint = NSTextField(labelWithString: "⌘⇧S 选区   ⌘⇧T 开始/暂停   ⌘⇧R 单次   ⌘⇧H 浮层")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .quaternaryLabelColor
        stack.addArrangedSubview(hint)

        // Every section spans the same width — the column's content area.
        for section in stack.arrangedSubviews {
            section.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor, constant: titleBarInset),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),

            scroll.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 14),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),

            stack.topAnchor.constraint(equalTo: doc.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor)
        ])
        return container
    }

    // MARK: - Right column (translation log)

    private func makeRightColumn() -> NSView {
        let container = NSView()

        let header = NSTextField(labelWithString: "翻译记录")
        header.font = .systemFont(ofSize: 13, weight: .semibold)
        header.textColor = .labelColor
        header.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)

        logCountLabel.font = .systemFont(ofSize: 11)
        logCountLabel.textColor = .tertiaryLabelColor
        logCountLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(logCountLabel)

        logScroll.drawsBackground = false
        logScroll.hasVerticalScroller = true
        logScroll.autohidesScrollers = true
        logScroll.scrollerStyle = .overlay
        logScroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(logScroll)

        let logDoc = FlippedView()
        logDoc.translatesAutoresizingMaskIntoConstraints = false
        logScroll.documentView = logDoc

        logStack.orientation = .vertical
        logStack.spacing = 8
        logStack.alignment = .leading
        logStack.edgeInsets = NSEdgeInsets(top: 4, left: 20, bottom: 24, right: 20)
        logStack.translatesAutoresizingMaskIntoConstraints = false
        logDoc.addSubview(logStack)

        logPlaceholder.font = .systemFont(ofSize: 12)
        logPlaceholder.textColor = .quaternaryLabelColor
        logPlaceholder.alignment = .center
        logPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(logPlaceholder)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: titleBarInset),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            logCountLabel.firstBaselineAnchor.constraint(equalTo: header.firstBaselineAnchor),
            logCountLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            logScroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            logScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            logScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            logScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            logDoc.topAnchor.constraint(equalTo: logScroll.contentView.topAnchor),
            logDoc.leadingAnchor.constraint(equalTo: logScroll.contentView.leadingAnchor),
            logDoc.trailingAnchor.constraint(equalTo: logScroll.contentView.trailingAnchor),
            logDoc.widthAnchor.constraint(equalTo: logScroll.contentView.widthAnchor),

            logStack.topAnchor.constraint(equalTo: logDoc.topAnchor),
            logStack.leadingAnchor.constraint(equalTo: logDoc.leadingAnchor),
            logStack.trailingAnchor.constraint(equalTo: logDoc.trailingAnchor),
            logStack.bottomAnchor.constraint(equalTo: logDoc.bottomAnchor),

            logPlaceholder.centerXAnchor.constraint(equalTo: logScroll.centerXAnchor),
            logPlaceholder.centerYAnchor.constraint(equalTo: logScroll.centerYAnchor)
        ])
        return container
    }

    private func rebuildLog() {
        logStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for entry in logEntries {
            logStack.addArrangedSubview(logEntryView(original: entry.original, translated: entry.translated))
        }
        updateLogChrome()
        DispatchQueue.main.async { [weak self] in
            self?.logScroll.contentView.scroll(to: .zero)
            self?.logScroll.reflectScrolledClipView(self!.logScroll.contentView)
        }
    }

    private func updateLogChrome() {
        logPlaceholder.isHidden = !logEntries.isEmpty
        logCountLabel.stringValue = logEntries.isEmpty ? "" : "\(logEntries.count) 条"
    }

    private func logEntryView(original: String, translated: String) -> NSView {
        let cardView = glassPanel()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 5
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 11, left: 14, bottom: 11, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stack)

        let src = wrappingLabel(original, font: .systemFont(ofSize: 12, weight: .medium), color: .secondaryLabelColor, maxLines: 3)
        let dst = wrappingLabel(translated, font: .systemFont(ofSize: 13, weight: .regular), color: Self.accent, maxLines: 6)
        stack.addArrangedSubview(src)
        stack.addArrangedSubview(dst)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cardView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor)
        ])
        return cardView
    }

    // MARK: - Building blocks

    /// A translucent rounded panel — the "glass card" used for sections and log rows.
    private func glassPanel() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = Self.cardFill.cgColor
        view.layer?.cornerRadius = 12
        view.layer?.cornerCurve = .continuous
        view.layer?.borderWidth = 1
        view.layer?.borderColor = Self.cardStroke.cgColor
        return view
    }

    /// A titled group of rows — no visible container, just a heading + aligned rows.
    private func card(title: String, rows: [NSView]) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 9
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        titleLabel.textColor = .tertiaryLabelColor
        stack.addArrangedSubview(titleLabel)
        stack.setCustomSpacing(10, after: titleLabel)

        rows.forEach { rowView in
            stack.addArrangedSubview(rowView)
            rowView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func row(_ label: String, _ control: NSView, suffix: String? = nil) -> NSView {
        let r = NSStackView()
        r.orientation = .horizontal
        r.spacing = 10
        r.alignment = .firstBaseline

        let l = NSTextField(labelWithString: label)
        l.alignment = .right
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = .secondaryLabelColor
        l.setContentHuggingPriority(.required, for: .horizontal)
        l.widthAnchor.constraint(equalToConstant: 64).isActive = true
        r.addArrangedSubview(l)

        control.translatesAutoresizingMaskIntoConstraints = false
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        r.addArrangedSubview(control)

        if let suffix {
            let s = NSTextField(labelWithString: suffix)
            s.font = .systemFont(ofSize: 10)
            s.textColor = .quaternaryLabelColor
            s.setContentHuggingPriority(.required, for: .horizontal)
            s.setContentCompressionResistancePriority(.required, for: .horizontal)
            r.addArrangedSubview(s)
        }
        return r
    }

    private func styleField(_ field: NSTextField) {
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: 12)
        field.controlSize = .regular
    }

    private func wrappingLabel(_ text: String, font: NSFont, color: NSColor, maxLines: Int) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = color
        label.isSelectable = true
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = maxLines
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    // MARK: - Action block

    private func makeActionBlock() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Status line
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.textColor = .secondaryLabelColor
        let statusRow = NSStackView(views: [statusDot, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 7
        statusRow.alignment = .centerY
        stack.addArrangedSubview(statusRow)
        stack.setCustomSpacing(11, after: statusRow)

        // Primary actions
        startButton.bezelStyle = .rounded
        startButton.controlSize = .large
        startButton.keyEquivalent = "\r"
        startButton.bezelColor = Self.accent
        startButton.target = self
        startButton.action = #selector(toggleRunning)

        let selectBtn = textButton("选择区域", #selector(selectRegion))
        let transBtn = textButton("立即翻译", #selector(translateNow))
        let overlayBtn = textButton("浮层", #selector(toggleOverlay))

        let primaryRow = NSStackView(views: [startButton, selectBtn])
        primaryRow.orientation = .horizontal
        primaryRow.spacing = 8
        primaryRow.distribution = .fillEqually
        stack.addArrangedSubview(primaryRow)

        let secondaryRow = NSStackView(views: [transBtn, overlayBtn])
        secondaryRow.orientation = .horizontal
        secondaryRow.spacing = 8
        secondaryRow.distribution = .fillEqually
        stack.addArrangedSubview(secondaryRow)

        // Maintenance actions
        let saveBtn = textButton("保存设置", #selector(saveSettings))
        testAPIButton.target = self; testAPIButton.action = #selector(testAPI); testAPIButton.bezelStyle = .rounded
        selfTestButton.target = self; selfTestButton.action = #selector(runSelfTest); selfTestButton.bezelStyle = .rounded
        let maintRow = NSStackView(views: [saveBtn, testAPIButton, selfTestButton])
        maintRow.orientation = .horizontal
        maintRow.spacing = 8
        maintRow.distribution = .fillEqually
        stack.addArrangedSubview(maintRow)

        [primaryRow, secondaryRow, maintRow].forEach {
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return stack
    }

    private func textButton(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .large
        return b
    }

    // MARK: - Configuration

    private func loadConfiguration() {
        let c = configurationStore.configuration
        sourceLanguagePopup.selectItem(withTitle: c.sourceLanguage)
        targetLanguageField.stringValue = c.targetLanguage
        targetLanguageField.placeholderString = "简体中文"
        secretIDField.stringValue = c.credentialID
        secretIDField.placeholderString = "Tencent SecretId"
        secretKeyField.stringValue = c.apiSecret
        secretKeyField.placeholderString = "Tencent SecretKey"
        regionPopup.selectItem(withTitle: c.tencentRegion)
        pollingIntervalField.stringValue = String(format: "%.2f", c.pollingInterval)
        fontSizeField.stringValue = String(format: "%.0f", c.overlayFontSize)
        opacitySlider.doubleValue = c.overlayOpacity
    }

    private func saveCurrentConfiguration() {
        let target = targetLanguageField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        configurationStore.configuration = AppConfiguration(
            sourceLanguage: sourceLanguagePopup.selectedItem?.title ?? "Japanese",
            targetLanguage: target.isEmpty ? "简体中文" : target,
            pollingInterval: Double(pollingIntervalField.stringValue) ?? AppConfiguration.defaults.pollingInterval,
            credentialID: secretIDField.stringValue,
            apiSecret: secretKeyField.stringValue,
            tencentRegion: regionPopup.selectedItem?.title ?? AppConfiguration.defaults.tencentRegion,
            overlayOpacity: opacitySlider.doubleValue,
            overlayFontSize: Double(fontSizeField.stringValue) ?? AppConfiguration.defaults.overlayFontSize
        )
        coordinator?.reloadConfiguration()
    }

    private func updateRunningState() {
        let running = coordinator?.isRunning == true
        startButton.title = running ? "暂停" : "开始"
        statusDot.layer?.backgroundColor = (running ? Self.accent : NSColor.tertiaryLabelColor).cgColor
        if statusLabel.stringValue.isEmpty || statusLabel.stringValue == "未运行" || statusLabel.stringValue == "运行中" {
            statusLabel.stringValue = running ? "运行中" : "未运行"
        }
    }

    // MARK: - Actions

    @objc private func saveSettings() { saveCurrentConfiguration() }

    @objc private func testAPI() {
        saveCurrentConfiguration()
        testAPIButton.isEnabled = false
        Task { @MainActor in
            defer { testAPIButton.isEnabled = true }
            guard let c = coordinator else { return }
            do {
                let r = try await c.testCurrentProvider()
                appendLog(original: "[API 测试]", translated: r)
            } catch {
                appendLog(original: "[API 错误]", translated: error.localizedDescription)
            }
        }
    }

    @objc private func runSelfTest() {
        saveCurrentConfiguration()
        selfTestButton.isEnabled = false
        Task { @MainActor in
            defer { selfTestButton.isEnabled = true }
            guard let c = coordinator else { return }
            _ = await c.runSelfTest(anchor: window?.frame)
        }
    }

    @objc private func selectRegion() { saveCurrentConfiguration(); coordinator?.selectRegion() }
    @objc private func toggleRunning() { saveCurrentConfiguration(); coordinator?.toggleRunning(); updateRunningState() }
    @objc private func translateNow() { saveCurrentConfiguration(); coordinator?.translateCurrentRegion() }
    @objc private func toggleOverlay() { coordinator?.toggleOverlayVisibility() }
}
