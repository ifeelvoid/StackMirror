import Foundation

enum ContentTransformer {
    static func transform(_ source: String, configuration: AppConfiguration) -> String {
        var text = source.trimmingCharacters(in: .whitespacesAndNewlines)

        for phrase in configuration.template.removePhrases
            .split(separator: ",")
            .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter({ !$0.isEmpty }) {
            text = text.replacingOccurrences(of: phrase, with: "", options: [.caseInsensitive])
        }

        if configuration.template.replaceLineBreaks {
            text = text
                .components(separatedBy: .newlines)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n\n")
        }

        return [
            configuration.template.prefix.trimmingCharacters(in: .whitespacesAndNewlines),
            text.trimmingCharacters(in: .whitespacesAndNewlines),
            configuration.template.suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    static func URLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
    }
}
