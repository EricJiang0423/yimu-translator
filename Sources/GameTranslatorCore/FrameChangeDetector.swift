import Foundation

public struct FrameChangeDetector: Sendable {
    private var lastFingerprint: UInt64?

    public init() {}

    public mutating func shouldProcess(fingerprint: UInt64) -> Bool {
        guard lastFingerprint != fingerprint else {
            return false
        }
        lastFingerprint = fingerprint
        return true
    }

    public mutating func reset() {
        lastFingerprint = nil
    }
}
