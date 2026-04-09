import Foundation

public final class CommentStore: @unchecked Sendable {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func loadAll() -> [String: [PlanComment]] {
        guard let data = try? Data(contentsOf: fileURL),
              let comments = try? decoder.decode([String: [PlanComment]].self, from: data) else {
            return [:]
        }
        return comments
    }

    public func loadComments(for planPath: String) -> [PlanComment] {
        loadAll()[planPath] ?? []
    }

    public func saveComments(_ comments: [PlanComment], for planPath: String) throws {
        var allComments = loadAll()
        allComments[planPath] = comments
        let data = try encoder.encode(allComments)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
