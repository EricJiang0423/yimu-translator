import CoreGraphics
import Foundation
import GameTranslatorCore
import Vision

final class VisionOCRService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "yimu.ocr", qos: .userInitiated)

    private static let visionLanguageCodes: [String: String] = [
        "Japanese": "ja-JP",
        "Chinese (Simplified)": "zh-Hans",
        "Chinese (Traditional)": "zh-Hant",
        "Korean": "ko-KR",
        "English": "en-US",
        "French": "fr-FR",
        "German": "de-DE",
        "Spanish": "es-ES",
        "Italian": "it-IT",
        "Portuguese": "pt-BR",
        "Thai": "th-TH",
        "Vietnamese": "vi-VT"
    ]

    func recognizeText(in image: CGImage, sourceLanguage: String = "Japanese") async throws -> String {
        let visionLang = Self.visionLanguageCodes[sourceLanguage] ?? "ja-JP"
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                let request = VNRecognizeTextRequest()
                request.recognitionLanguages = [visionLang]
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.minimumTextHeight = 0.01

                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                    let observations = (request.results ?? [])
                        .sorted(by: Self.readingOrder)
                    let rawText = Self.groupIntoLines(observations)
                        .map { $0.joined() }
                        .joined(separator: "\n")
                    continuation.resume(returning: TextNormalizer.normalizeGameText(rawText))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static let lineThreshold: CGFloat = 0.02

    private static func groupIntoLines(_ observations: [VNRecognizedTextObservation]) -> [[String]] {
        var lines: [[String]] = []
        var currentLine: [String] = []
        var lastTop: CGFloat?

        for obs in observations {
            let top = obs.boundingBox.origin.y + obs.boundingBox.height
            if let last = lastTop, abs(top - last) > lineThreshold {
                lines.append(currentLine)
                currentLine = []
            }
            if let text = obs.topCandidates(1).first?.string {
                currentLine.append(text)
            }
            lastTop = top
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }
        return lines
    }

    private static func readingOrder(lhs: VNRecognizedTextObservation, rhs: VNRecognizedTextObservation) -> Bool {
        let lhsTop = lhs.boundingBox.origin.y + lhs.boundingBox.height
        let rhsTop = rhs.boundingBox.origin.y + rhs.boundingBox.height
        if abs(lhsTop - rhsTop) > 0.02 {
            return lhsTop > rhsTop
        }
        return lhs.boundingBox.origin.x < rhs.boundingBox.origin.x
    }
}
