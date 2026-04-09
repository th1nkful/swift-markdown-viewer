import Foundation

public enum MarkdownLineKind: Hashable, Sendable {
    case empty
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case blockquote(text: String)
    case bullet(text: String, checked: Bool?)
    case ordered(index: Int, text: String)
    case divider
    case codeFence(language: String?)
    case code(text: String)
}

public struct MarkdownLine: Hashable, Sendable, Identifiable {
    public let id: Int
    public let lineNumber: Int
    public let rawText: String
    public let kind: MarkdownLineKind
    public let attributedContent: AttributedString?

    public init(lineNumber: Int, rawText: String, kind: MarkdownLineKind, attributedContent: AttributedString? = nil) {
        self.id = lineNumber
        self.lineNumber = lineNumber
        self.rawText = rawText
        self.kind = kind
        self.attributedContent = attributedContent
    }
}

public struct MarkdownLineParser: Sendable {
    public init() {}

    public func parse(_ source: String) -> [MarkdownLine] {
        let lines = source.components(separatedBy: .newlines)
        var result: [MarkdownLine] = []
        var isInsideCodeFence = false

        for (index, rawLine) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                result.append(MarkdownLine(
                    lineNumber: lineNumber,
                    rawText: rawLine,
                    kind: .codeFence(language: language.isEmpty ? nil : language)
                ))
                isInsideCodeFence.toggle()
                continue
            }

            if isInsideCodeFence {
                result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: .code(text: rawLine)))
                continue
            }

            if trimmed.isEmpty {
                result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: .empty))
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: .divider))
                continue
            }

            if let heading = headingKind(from: trimmed) {
                result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: heading))
                continue
            }

            if trimmed.hasPrefix(">") {
                let text = String(trimmed.drop(while: { $0 == ">" || $0 == " " }))
                result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: .blockquote(text: text)))
                continue
            }

            if let bullet = bulletKind(from: trimmed) {
                result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: bullet))
                continue
            }

            if let ordered = orderedKind(from: trimmed) {
                result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: ordered))
                continue
            }

            result.append(MarkdownLine(lineNumber: lineNumber, rawText: rawLine, kind: .paragraph(text: rawLine)))
        }

        return result.map { line in
            MarkdownLine(
                lineNumber: line.lineNumber,
                rawText: line.rawText,
                kind: line.kind,
                attributedContent: attributedContent(for: line.kind)
            )
        }
    }

    private func attributedContent(for kind: MarkdownLineKind) -> AttributedString? {
        let text: String
        switch kind {
        case .heading(_, let t): text = t
        case .paragraph(let t): text = t
        case .blockquote(let t): text = t
        case .bullet(let t, _): text = t
        case .ordered(_, let t): text = t
        case .empty, .divider, .codeFence, .code: return nil
        }
#if canImport(AppKit)
        return try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
#else
        return nil
#endif
    }

    private func headingKind(from line: String) -> MarkdownLineKind? {
        let hashes = line.prefix { $0 == "#" }
        guard !hashes.isEmpty, hashes.count <= 6 else { return nil }
        let remainder = line.dropFirst(hashes.count)
        guard remainder.first == " " else { return nil }
        return .heading(level: hashes.count, text: remainder.trimmingCharacters(in: .whitespaces))
    }

    private func bulletKind(from line: String) -> MarkdownLineKind? {
        if line.hasPrefix("- [ ] ") { return .bullet(text: String(line.dropFirst(6)), checked: false) }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return .bullet(text: String(line.dropFirst(6)), checked: true) }
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
            return .bullet(text: String(line.dropFirst(2)), checked: nil)
        }
        return nil
    }

    private func orderedKind(from line: String) -> MarkdownLineKind? {
        let parts = line.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2, let index = Int(parts[0]), parts[1].first == " " else { return nil }
        return .ordered(index: index, text: String(parts[1].dropFirst()))
    }
}
