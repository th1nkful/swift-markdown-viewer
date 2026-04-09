import Foundation

public final class CommentStore: Sendable {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func loadAll() -> [String: [PlanComment]] {
        guard let data = try? Data(contentsOf: fileURL),
              let comments = try? JSONDecoder().decode([String: [PlanComment]].self, from: data) else {
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
        let data = try JSONEncoder().encode(allComments)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}
