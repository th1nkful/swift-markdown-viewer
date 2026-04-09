import Foundation

public struct WorkspaceConfiguration: Codable, Hashable, Sendable {
    public var extraDirectories: [WorkspaceDirectory]
    public var promptTemplate: String?

    public init(extraDirectories: [WorkspaceDirectory] = [], promptTemplate: String? = nil) {
        self.extraDirectories = extraDirectories
        self.promptTemplate = promptTemplate?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public final class WorkspaceStore: @unchecked Sendable {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> WorkspaceConfiguration {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? decoder.decode(WorkspaceConfiguration.self, from: data) else {
            return WorkspaceConfiguration()
        }
        return config
    }

    public func save(_ configuration: WorkspaceConfiguration) throws {
        let data = try encoder.encode(configuration)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
