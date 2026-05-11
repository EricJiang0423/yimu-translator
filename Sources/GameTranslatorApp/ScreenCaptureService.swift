import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class ScreenCaptureService {
    static var hasScreenCaptureAccess: Bool {
        CGPreflightScreenCaptureAccess()
    }

    @discardableResult
    static func requestScreenCaptureAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func capture(region appKitRegion: CGRect) async throws -> CGImage {
        guard Self.hasScreenCaptureAccess else {
            _ = Self.requestScreenCaptureAccess()
            throw ScreenCaptureError.permissionDenied
        }
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
            return "Screen Recording permission is not enabled. Enable it for Terminal or this app in System Settings, then restart."
        case .displayNotFound:
            return "Unable to find the selected display."
        }
    }
}
