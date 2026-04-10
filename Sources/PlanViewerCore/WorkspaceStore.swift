import Foundation

public struct WorkspaceConfiguration: Codable, Hashable, Sendable {
    public var promptTemplate: String?

    public init(promptTemplate: String? = nil) {
        self.promptTemplate = promptTemplate?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public final class WorkspaceStore: Sendable {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> WorkspaceConfiguration {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(WorkspaceConfiguration.self, from: data) else {
            return WorkspaceConfiguration()
        }
        return config
    }

    public func save(_ configuration: WorkspaceConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
