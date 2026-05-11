import AppKit
import CoreGraphics
// Newer SDKs (Xcode 16+) ship ScreenCaptureKit without Sendable annotations, which
// trips Swift 6 strict-concurrency checks. This class is @MainActor, so the awaited
// calls hop back to the main actor anyway — downgrade the cross-module diagnostics.
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenCaptureService {
    /// Tracks whether we've called CGRequestScreenCaptureAccess this session.
    /// On Sequoia, CGPreflightScreenCaptureAccess() is unreliable for unsigned
    /// apps — it can return false even when the app actually has permission.
    /// Solution: skip preflight entirely. Just try ScreenCaptureKit directly.
    /// The first call triggers the OS permission dialog; if it fails we surface
    /// the error and let the user retry after configuring Settings.
    private static var requestedAccessThisSession = false

    /// Call this at startup so the OS dialog appears at a predictable time
    /// (not suddenly mid-capture). At most once per session.
    static func requestAccessIfNeeded() {
        guard !requestedAccessThisSession else { return }
        requestedAccessThisSession = true
        CGRequestScreenCaptureAccess()
    }

    func capture(region appKitRegion: CGRect) async throws -> CGImage {
        // No preflight — just try ScreenCaptureKit. The OS handles the dialog.
        guard let screen = screen(containing: appKitRegion),
              let displayID = displayID(for: screen) else {
            throw ScreenCaptureError.displayNotFound
        }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            throw ScreenCaptureError.permissionDenied(underlying: error)
        }
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

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            throw ScreenCaptureError.permissionDenied(underlying: error)
        }
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
    case permissionDenied(underlying: Error? = nil)
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let underlying):
            if let e = underlying {
                return "截取屏幕失败：\(e.localizedDescription)\n\n请在「系统设置 → 隐私与安全性 → 屏幕录制」中勾选「译幕」，然后重试；如果已勾选仍需重启 App（⌘Q 后重新打开）。"
            }
            return "屏幕录制失败。请在「系统设置 → 隐私与安全性 → 屏幕录制」中勾选「译幕」，然后重启 App。"
        case .displayNotFound:
            return "找不到对应显示器。"
        }
    }
}
