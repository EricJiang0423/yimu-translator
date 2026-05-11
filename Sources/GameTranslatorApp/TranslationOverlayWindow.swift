import AppKit
import GameTranslatorCore

@MainActor
final class TranslationOverlayWindow: NSPanel {
    private let chromeView = OverlayChromeView()
    private let minimumPanelSize = CGSize(width: 260, height: 76)
    private let maximumPanelSize = CGSize(width: 900, height: 520)

    private var lastRegion: CGRect?
    private var lastText = ""
    private var lastConfiguration: AppConfiguration?
    private var userPlaced = false
    private var closedByUser = false

    init() {
        super.init(
            contentRect: CGRect(x: 0, y: 0, width: 420, height: 110),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        contentView = chromeView

        chromeView.onClose = { [weak self] in
            self?.closeFromOverlayButton()
        }
        chromeView.onRecenter = { [weak self] in
            self?.recenter()
        }
        chromeView.onDragFrame = { [weak self] frame in
            self?.applyUserFrame(frame)
        }
        chromeView.onResizeFrame = { [weak self] frame in
            self?.applyUserFrame(frame)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var currentText: String {
        chromeView.currentText
    }

    func show(text: String, near region: CGRect, configuration: AppConfiguration, forceVisible: Bool = false) {
        let regionChanged = lastRegion.map { !$0.equalTo(region) } ?? true
        lastRegion = region
        lastText = text
        lastConfiguration = configuration

        if regionChanged {
            userPlaced = false
            closedByUser = false
        }
        if forceVisible {
            closedByUser = false
        }

        chromeView.update(
            text: text,
            opacity: configuration.clampedOverlayOpacity,
            fontSize: configuration.clampedOverlayFontSize
        )

        if !userPlaced || regionChanged {
            setFrame(autoFrame(for: text, near: region, configuration: configuration), display: true)
        }

        guard !closedByUser else {
            return
        }
        orderFrontRegardless()
    }

    func showError(_ message: String, near region: CGRect?, configuration: AppConfiguration) {
        let targetRegion = region ?? lastRegion ?? CGRect(x: 240, y: 240, width: 420, height: 90)
        show(text: "Error: \(message)", near: targetRegion, configuration: configuration)
    }

    func toggleVisibility() {
        if isVisible {
            closeFromOverlayButton()
            return
        }

        closedByUser = false
        if !lastText.isEmpty, let region = lastRegion, let configuration = lastConfiguration, !userPlaced {
            setFrame(autoFrame(for: lastText, near: region, configuration: configuration), display: true)
        }
        orderFrontRegardless()
    }

    func hide() {
        closedByUser = false
        orderOut(nil)
    }

    private func closeFromOverlayButton() {
        closedByUser = true
        orderOut(nil)
    }

    private func recenter() {
        closedByUser = false
        userPlaced = false
        guard let region = lastRegion, let configuration = lastConfiguration else {
            orderFrontRegardless()
            return
        }
        setFrame(autoFrame(for: lastText, near: region, configuration: configuration), display: true)
        orderFrontRegardless()
    }

    private func applyUserFrame(_ proposedFrame: CGRect) {
        userPlaced = true
        setFrame(constrainedFrame(proposedFrame), display: true)
    }

    private func autoFrame(for text: String, near region: CGRect, configuration: AppConfiguration) -> CGRect {
        let width = min(max(region.width, 300), maximumPanelSize.width)
        let font = NSFont.systemFont(ofSize: configuration.clampedOverlayFontSize, weight: .medium)
        let textRect = NSString(string: text).boundingRect(
            with: CGSize(width: width - OverlayChromeView.Metrics.horizontalTextInset * 2, height: 700),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let height = min(
            max(
                ceil(textRect.height)
                    + OverlayChromeView.Metrics.topBarHeight
                    + OverlayChromeView.Metrics.verticalTextInset
                    + OverlayChromeView.Metrics.bottomInset,
                minimumPanelSize.height
            ),
            maximumPanelSize.height
        )

        let screenFrame = screenFrame(containing: region)
        var frame = CGRect(x: region.minX, y: region.maxY + 8, width: width, height: height)
        if frame.maxY > screenFrame.maxY {
            frame.origin.y = region.minY - height - 8
        }
        return constrainedFrame(frame)
    }

    private func constrainedFrame(_ frame: CGRect) -> CGRect {
        var constrained = frame.integral
        constrained.size.width = min(max(constrained.width, minimumPanelSize.width), maximumPanelSize.width)
        constrained.size.height = min(max(constrained.height, minimumPanelSize.height), maximumPanelSize.height)

        let visibleFrame = screenFrame(containing: constrained)
        let availableWidth = max(120, visibleFrame.width - 16)
        let availableHeight = max(80, visibleFrame.height - 16)
        constrained.size.width = min(constrained.width, availableWidth)
        constrained.size.height = min(constrained.height, availableHeight)
        constrained.origin.x = min(max(constrained.origin.x, visibleFrame.minX + 8), visibleFrame.maxX - constrained.width - 8)
        constrained.origin.y = min(max(constrained.origin.y, visibleFrame.minY + 8), visibleFrame.maxY - constrained.height - 8)
        return constrained.integral
    }

    private func screenFrame(containing rect: CGRect) -> CGRect {
        let point = CGPoint(x: rect.midX, y: rect.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.screens.first { $0.frame.intersects(rect) }
            ?? NSScreen.main
        return screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }
}

final class OverlayChromeView: NSView {
    enum Metrics {
        static let topBarHeight: CGFloat = 28
        static let horizontalTextInset: CGFloat = 14
        static let verticalTextInset: CGFloat = 8
        static let bottomInset: CGFloat = 16
        static let controlSize: CGFloat = 22
        static let resizeGripSize: CGFloat = 22
    }

    private let label = NSTextField(labelWithString: "")
    private let closeButton = OverlayControlButton(kind: .close)
    private let recenterButton = OverlayControlButton(kind: .recenter)
    private let resizeGrip = OverlayResizeGripView()
    private var backgroundOpacity: CGFloat = 0.72
    private var dragStartMouse: CGPoint?
    private var dragStartFrame: CGRect?

    var onClose: (() -> Void)?
    var onRecenter: (() -> Void)?
    var onDragFrame: ((CGRect) -> Void)?
    var onResizeFrame: ((CGRect) -> Void)?

    var currentText: String {
        label.stringValue
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        label.textColor = .white
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.alignment = .left
        label.isSelectable = false
        label.backgroundColor = .clear
        addSubview(label)

        closeButton.toolTip = "Close overlay. Use Cmd+Shift+H or Translate Now to show it again."
        closeButton.onPress = { [weak self] in
            self?.onClose?()
        }
        addSubview(closeButton)

        recenterButton.toolTip = "Return overlay to the selected text area."
        recenterButton.onPress = { [weak self] in
            self?.onRecenter?()
        }
        addSubview(recenterButton)

        resizeGrip.onFrameChange = { [weak self] frame in
            self?.onResizeFrame?(frame)
        }
        addSubview(resizeGrip)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func update(text: String, opacity: Double, fontSize: Double) {
        label.stringValue = text
        label.font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        backgroundOpacity = CGFloat(opacity)
        needsDisplay = true
        needsLayout = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.black.withAlphaComponent(backgroundOpacity).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        NSColor.white.withAlphaComponent(0.08).setFill()
        let barRect = CGRect(
            x: 0,
            y: bounds.height - Metrics.topBarHeight,
            width: bounds.width,
            height: Metrics.topBarHeight
        )
        NSBezierPath(rect: barRect).fill()

        NSColor.white.withAlphaComponent(0.26).setStroke()
        let handle = NSBezierPath()
        let y = bounds.height - Metrics.topBarHeight / 2
        handle.move(to: CGPoint(x: 14, y: y))
        handle.line(to: CGPoint(x: min(84, bounds.width - 72), y: y))
        handle.lineWidth = 2
        handle.stroke()
    }

    override func layout() {
        super.layout()

        let controlY = bounds.height - Metrics.topBarHeight + 3
        closeButton.frame = CGRect(
            x: bounds.width - Metrics.controlSize - 6,
            y: controlY,
            width: Metrics.controlSize,
            height: Metrics.controlSize
        )
        recenterButton.frame = CGRect(
            x: closeButton.frame.minX - Metrics.controlSize - 6,
            y: controlY,
            width: Metrics.controlSize,
            height: Metrics.controlSize
        )
        resizeGrip.frame = CGRect(
            x: bounds.width - Metrics.resizeGripSize,
            y: 0,
            width: Metrics.resizeGripSize,
            height: Metrics.resizeGripSize
        )

        label.frame = CGRect(
            x: Metrics.horizontalTextInset,
            y: Metrics.bottomInset,
            width: max(0, bounds.width - Metrics.horizontalTextInset * 2),
            height: max(0, bounds.height - Metrics.topBarHeight - Metrics.bottomInset - Metrics.verticalTextInset)
        )
    }

    override func mouseDown(with event: NSEvent) {
        guard isPointInDragBar(event.locationInWindow) else {
            super.mouseDown(with: event)
            return
        }
        dragStartMouse = NSEvent.mouseLocation
        dragStartFrame = window?.frame
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartMouse, var frame = dragStartFrame else {
            super.mouseDragged(with: event)
            return
        }

        let mouse = NSEvent.mouseLocation
        frame.origin.x += mouse.x - dragStartMouse.x
        frame.origin.y += mouse.y - dragStartMouse.y
        onDragFrame?(frame)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouse = nil
        dragStartFrame = nil
    }

    private func isPointInDragBar(_ windowPoint: CGPoint) -> Bool {
        let point = convert(windowPoint, from: nil)
        let barRect = CGRect(x: 0, y: bounds.height - Metrics.topBarHeight, width: bounds.width, height: Metrics.topBarHeight)
        return barRect.contains(point)
            && !closeButton.frame.contains(point)
            && !recenterButton.frame.contains(point)
    }
}

final class OverlayControlButton: NSView {
    enum Kind {
        case close
        case recenter
    }

    private let kind: Kind
    private var isHovering = false
    private var isPressed = false
    private var trackingArea: NSTrackingArea?

    var onPress: (() -> Void)?

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        isPressed = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        isPressed = true
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let shouldFire = isPressed && bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        needsDisplay = true
        if shouldFire {
            onPress?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let fillAlpha: CGFloat = isPressed ? 0.28 : (isHovering ? 0.18 : 0.10)
        NSColor.white.withAlphaComponent(fillAlpha).setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()

        NSColor.white.withAlphaComponent(0.92).setStroke()
        switch kind {
        case .close:
            drawCloseGlyph()
        case .recenter:
            drawRecenterGlyph()
        }
    }

    private func drawCloseGlyph() {
        let rect = bounds.insetBy(dx: 7, dy: 7)
        let path = NSBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.stroke()
    }

    private func drawRecenterGlyph() {
        let rect = bounds.insetBy(dx: 6, dy: 6)
        NSBezierPath(ovalIn: rect).stroke()

        let path = NSBezierPath()
        path.move(to: CGPoint(x: bounds.midX, y: rect.minY - 2))
        path.line(to: CGPoint(x: bounds.midX, y: rect.minY + 3))
        path.move(to: CGPoint(x: bounds.midX, y: rect.maxY - 3))
        path.line(to: CGPoint(x: bounds.midX, y: rect.maxY + 2))
        path.move(to: CGPoint(x: rect.minX - 2, y: bounds.midY))
        path.line(to: CGPoint(x: rect.minX + 3, y: bounds.midY))
        path.move(to: CGPoint(x: rect.maxX - 3, y: bounds.midY))
        path.line(to: CGPoint(x: rect.maxX + 2, y: bounds.midY))
        path.lineWidth = 1.4
        path.lineCapStyle = .round
        path.stroke()
    }
}

final class OverlayResizeGripView: NSView {
    private var dragStartMouse: CGPoint?
    private var dragStartFrame: CGRect?
    var onFrameChange: ((CGRect) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartMouse = NSEvent.mouseLocation
        dragStartFrame = window?.frame
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStartMouse, var frame = dragStartFrame else {
            return
        }

        let mouse = NSEvent.mouseLocation
        let deltaX = mouse.x - dragStartMouse.x
        let deltaY = mouse.y - dragStartMouse.y
        frame.size.width += deltaX
        frame.size.height -= deltaY
        frame.origin.y += deltaY
        onFrameChange?(frame)
    }

    override func mouseUp(with event: NSEvent) {
        dragStartMouse = nil
        dragStartFrame = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.white.withAlphaComponent(0.32).setStroke()
        for offset in stride(from: CGFloat(6), through: CGFloat(16), by: CGFloat(5)) {
            let path = NSBezierPath()
            path.move(to: CGPoint(x: bounds.maxX - offset, y: 3))
            path.line(to: CGPoint(x: bounds.maxX - 3, y: offset))
            path.lineWidth = 1
            path.stroke()
        }
    }
}
