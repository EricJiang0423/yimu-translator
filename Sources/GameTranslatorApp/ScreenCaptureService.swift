import AppKit
import CoreGraphics
// Newer SDKs (Xcode 16+) ship ScreenCaptureKit without Sendable annotations, which
// trips Swift 6 strict-concurrency checks. This class is @MainActor, so the awaited
// calls hop back to the main actor anyway — downgrade the cross-module diagnostics.
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenCaptureService {
    /// Tracks whether we've called CGRequestScreenCaptureAccess this session
    /// so we don't spam the OS dialog on every poll cycle.
    private static var requestedAccessThisSession = false

    static var hasScreenCaptureAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Ensures screen-recording access is granted.
    /// Calls `CGRequestScreenCaptureAccess()` at most once per session.
    /// If the user grants through the system dialog, the permission only takes
    /// effect *after* the current process is restarted — so we always throw
    /// permissionDenied here and tell the user to restart.
    static func ensureCaptureAccess() throws {
        if CGPreflightScreenCaptureAccess() { return }

        if !requestedAccessThisSession {
            requestedAccessThisSession = true
            CGRequestScreenCaptureAccess()
        }

        throw ScreenCaptureError.permissionDenied
    }

    func capture(region appKitRegion: CGRect) async throws -> CGImage {
        try Self.ensureCaptureAccess()
        guard let screen = screen(containing: appKitRegion),
              let displayID = displayID(for: screen) else {
            throw ScreenCaptureError.displayNotFound
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenCaptureError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let sourceRect = displayLocalRect(for: appKitRegion, in: screen)
        let scale = max(Double(filter.pointPixelScale), screen.backingScaleFactor)

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = sourceRect
        configuration.width = max(1, Int(sourceRect.width * scale))
        configuration.height = max(1, Int(sourceRect.height * scale))
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.scalesToFit = true

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    func fingerprint(for image: CGImage) -> UInt64 {
        let width = 32
        let height = 32
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: height * bytesPerRow)

        buffer.withUnsafeMutableBytes { pointer in
            guard let context = CGContext(
                data: pointer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return
            }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        var hash: UInt64 = 14695981039346656037
        for byte in buffer {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash
    }

    private func screen(containing rect: CGRect) -> NSScreen? {
        let midpoint = CGPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(midpoint) }
            ?? NSScreen.screens.first { $0.frame.intersects(rect) }
            ?? NSScreen.main
    }

    private func displayID(for screen: NSScreen) -> CGDirectDisplayID? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }

    private func displayLocalRect(for rect: CGRect, in screen: NSScreen) -> CGRect {
        return CGRect(
            x: rect.minX - screen.frame.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        ).integral
    }
}

enum ScreenCaptureError: LocalizedError {
    case permissionDenied
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "屏幕录制权限未开启。请在「系统设置 → 隐私与安全性 → 屏幕录制」中勾选「译幕」，然后完全退出（⌘Q）后重新打开 App。"
        case .displayNotFound:
            return "Unable to find the selected display."
        }
    }
}
