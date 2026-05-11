import AppKit

@MainActor
final class RegionSelectionController {
    private var windows: [SelectionWindow] = []
    private var completion: ((CGRect?) -> Void)?

    func begin(completion: @escaping (CGRect?) -> Void) {
        self.completion = completion
        windows = NSScreen.screens.map { screen in
            let window = SelectionWindow(screen: screen)
            let view = SelectionView(frame: window.contentView?.bounds ?? .zero)
            view.onComplete = { [weak self] rect in self?.finish(rect) }
            view.onCancel = { [weak self] in self?.finish(nil) }
            window.onCancel = { [weak self] in self?.finish(nil) }
            window.contentView = view
            return window
        }
        windows.forEach { window in
            window.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func finish(_ rect: CGRect?) {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        let callback = completion
        completion = nil
        callback?(rect)
    }
}

final class SelectionWindow: NSWindow {
    var onCancel: (() -> Void)?

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
}

final class SelectionView: NSView {
    var onComplete: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var isFlipped: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.28).setFill()
        bounds.fill()

        // Instruction text
        let hint = "Drag to select the game text area — Press Esc to cancel"
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.8)
        ]
        let hintSize = (hint as NSString).size(withAttributes: attr)
        let hintPoint = CGPoint(
            x: (bounds.width - hintSize.width) / 2,
            y: bounds.height * 0.35
        )
        (hint as NSString).draw(at: hintPoint, withAttributes: attr)

        guard let selection = selectionRect else { return }

        NSColor.clear.setFill()
        selection.fill(using: .clear)
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(rect: selection)
        path.lineWidth = 2
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let selection = selectionRect, selection.width >= 20, selection.height >= 12 else {
            onCancel?()
            return
        }
        let windowRect = convert(selection, to: nil)
        let screenRect = window?.convertToScreen(windowRect) ?? selection
        onComplete?(screenRect.integral)
    }

    private var selectionRect: CGRect? {
        guard let startPoint, let currentPoint else {
            return nil
        }
        return CGRect(
            x: min(startPoint.x, currentPoint.x),
            y: min(startPoint.y, currentPoint.y),
            width: abs(startPoint.x - currentPoint.x),
            height: abs(startPoint.y - currentPoint.y)
        )
    }
}
