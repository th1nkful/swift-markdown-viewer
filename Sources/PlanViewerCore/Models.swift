import Foundation

public struct WorkspaceDirectory: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var path: String

    public init(id: UUID = UUID(), name: String? = nil, path: String) {
        self.id = id
        self.path = path
        let expanded = (path as NSString).expandingTildeInPath
        self.name = name ?? URL(fileURLWithPath: expanded).lastPathComponent
    }

    public var url: URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }
}

public struct PlanDocument: Identifiable, Hashable, Sendable {
    public let id: String
    public let url: URL
    public let workspaceName: String
    public let workspaceURL: URL
    public let modifiedAt: Date

    public init(url: URL, workspaceName: String, workspaceURL: URL, modifiedAt: Date) {
        self.id = url.path
        self.url = url
        self.workspaceName = workspaceName
        self.workspaceURL = workspaceURL
        self.modifiedAt = modifiedAt
    }

    public var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    public var pathDisplay: String {
        url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    public func loadContents() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

public enum CommentAnchor: Codable, Hashable, Sendable {
    case file
    case lineRange(start: Int, end: Int)
}

public struct PlanComment: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var anchor: CommentAnchor
    public var text: String
    public var createdAt: Date

    public init(id: UUID = UUID(), anchor: CommentAnchor, text: String, createdAt: Date = Date()) {
        self.id = id
        self.anchor = anchor
        self.text = text
        self.createdAt = createdAt
    }
}

public struct PlanPromptBuilder: Sendable {
    public static let defaultTemplate = """
    {{file_comments_section}}

    {{inline_comments_section}}
    """

    public init() {}

    public func buildPrompt(for comments: [PlanComment], template: String? = nil) -> String {
        let fileComments = comments.compactMap { comment -> String? in
            guard case .file = comment.anchor else { return nil }
            let trimmed = comment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        let inlineComments = comments.compactMap { comment -> (Int, Int, String)? in
            guard case .lineRange(let start, let end) = comment.anchor else { return nil }
            let trimmed = comment.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : (start, end, trimmed)
        }.sorted { lhs, rhs in
            lhs.0 == rhs.0 ? lhs.1 < rhs.1 : lhs.0 < rhs.0
        }

        guard !fileComments.isEmpty || !inlineComments.isEmpty else { return "" }

        let fileCommentsText = fileComments.joined(separator: "\n\n")
        let inlineCommentsText = inlineComments.map { start, end, text in
            if start == end {
                return "Around L\(start): \(text)"
            }
            return "Around L\(start) to L\(end): \(text)"
        }.joined(separator: "\n")

        let fileSection = fileCommentsText.isEmpty ? "" : """
        Here is feedback on the plan:
        \(fileCommentsText)
        """

        let inlineSection = inlineCommentsText.isEmpty ? "" : """
        Other feedback:
        \(inlineCommentsText)
        """

        let resolvedTemplate = template?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? template ?? Self.defaultTemplate
            : Self.defaultTemplate

        let prompt = resolvedTemplate
            .replacingOccurrences(of: "{{file_comments_section}}", with: fileSection)
            .replacingOccurrences(of: "{{inline_comments_section}}", with: inlineSection)
            .replacingOccurrences(of: "{{file_comments}}", with: fileCommentsText)
            .replacingOccurrences(of: "{{inline_comments}}", with: inlineCommentsText)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !prompt.isEmpty else { return "" }

        if let whitespacePattern = try? NSRegularExpression(pattern: #"\n{3,}"#) {
            let range = NSRange(prompt.startIndex..<prompt.endIndex, in: prompt)
            return whitespacePattern.stringByReplacingMatches(in: prompt, options: [], range: range, withTemplate: "\n\n")
        }

        return prompt
    }
}
