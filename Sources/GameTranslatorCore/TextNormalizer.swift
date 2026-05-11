import Foundation

public enum TextNormalizer {
    public static func normalizeGameText(_ rawText: String) -> String {
        let unified = rawText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "　", with: " ")

        var previous: String?
        let lines = unified
            .components(separatedBy: .newlines)
            .map { collapseWhitespace($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { line in
                defer { previous = line }
                return previous != line
            }

        return lines.joined(separator: "\n")
    }

    public static func containsRecognizableText(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x309F: return true // Hiragana
            case 0x30A0...0x30FF, 0x31F0...0x31FF: return true // Katakana
            case 0x4E00...0x9FFF, 0x3400...0x4DBF: return true // CJK
            case 0xAC00...0xD7AF: return true // Hangul
            case 0x0E00...0x0E7F: return true // Thai
            case 0x0100...0x024F: return true // Latin Extended
            case 0x0400...0x04FF: return true // Cyrillic
            case 0x0021...0x007E: return true // ASCII letters/digits/punctuation
            default:
                return false
            }
        }
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
