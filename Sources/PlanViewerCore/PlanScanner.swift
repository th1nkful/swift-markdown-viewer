import Foundation

public struct WorkspaceTarget: Hashable, Sendable {
    public var name: String
    public var url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public struct PlanScanner: Sendable {
    public init() {}

    public func scan(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) -> [PlanDocument] {
        let mapping = buildGlobalPlanMapping(homeDirectory: homeDirectory)

        return defaultWorkspaceTargets(homeDirectory: homeDirectory)
            .flatMap(scanWorkspace)
            .map { doc in
                guard let projectName = mapping[doc.url.path] else { return doc }
                return PlanDocument(url: doc.url, workspaceName: projectName, workspaceURL: doc.workspaceURL, modifiedAt: doc.modifiedAt, h1Title: doc.h1Title)
            }
            .sorted { lhs, rhs in
                lhs.modifiedAt == rhs.modifiedAt ? lhs.url.path < rhs.url.path : lhs.modifiedAt > rhs.modifiedAt
            }
    }

    public func defaultWorkspaceTargets(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) -> [WorkspaceTarget] {
        [WorkspaceTarget(name: "~/.claude/plans", url: homeDirectory.appendingPathComponent(".claude/plans", isDirectory: true))]
    }

    public func scanWorkspace(_ target: WorkspaceTarget) -> [PlanDocument] {
        guard FileManager.default.fileExists(atPath: target.url.path) else { return [] }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: target.url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            return []
        }

        var plans: [PlanDocument] = []
        var seen = Set<String>()
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            guard seen.insert(fileURL.standardizedFileURL.path).inserted else { continue }
            plans.append(PlanDocument(
                url: fileURL,
                workspaceName: target.name,
                workspaceURL: target.url,
                modifiedAt: values?.contentModificationDate ?? .distantPast,
                h1Title: extractH1Title(from: fileURL)
            ))
        }

        return plans
    }

    // MARK: - Global Plan Mapping

    private func buildGlobalPlanMapping(homeDirectory: URL) -> [String: String] {
        let projectsDir = homeDirectory.appendingPathComponent(".claude/projects", isDirectory: true)
        guard let projectDirURLs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [:] }

        let needle = Data("planFilePath".utf8)
        var mapping: [String: String] = [:]

        for projectDirURL in projectDirURLs {
            guard (try? projectDirURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }

            guard let files = try? FileManager.default.contentsOfDirectory(
                at: projectDirURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }
            guard !jsonlFiles.isEmpty else { continue }

            var projectName: String?
            for file in jsonlFiles {
                if let name = extractProjectName(from: file) {
                    projectName = name
                    break
                }
            }
            guard let name = projectName else { continue }

            for jsonlFile in jsonlFiles {
                guard let data = try? Data(contentsOf: jsonlFile, options: .mappedIfSafe),
                      data.range(of: needle) != nil,
                      let content = String(data: data, encoding: .utf8) else { continue }

                for planPath in extractPlanFilePaths(from: content) {
                    mapping[planPath] = name
                }
            }
        }

        return mapping
    }

    private func extractProjectName(from jsonlFile: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: jsonlFile) else { return nil }
        defer { handle.closeFile() }

        // Read enough to find a line with cwd (first line may be permission-mode, file-history-snapshot, etc.)
        let data = handle.readData(ofLength: 65536)
        guard let text = String(data: data, encoding: .utf8) else { return nil }

        for line in text.split(separator: "\n", maxSplits: 20).prefix(20) {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let cwd = json["cwd"] as? String, !cwd.isEmpty else { continue }
            return gitRootName(for: cwd)
        }
        return nil
    }

    private func gitRootName(for cwd: String) -> String {
        var current = URL(fileURLWithPath: cwd)
        while current.path != "/" {
            let gitPath = current.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: gitPath.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    return current.lastPathComponent
                }
                // Worktree: .git is a file pointing to the real repo
                if let content = try? String(contentsOf: gitPath, encoding: .utf8),
                   content.hasPrefix("gitdir: ") {
                    let gitdir = String(content.dropFirst(8)).trimmingCharacters(in: .whitespacesAndNewlines)
                    let gitdirURL: URL
                    if gitdir.hasPrefix("/") {
                        gitdirURL = URL(fileURLWithPath: gitdir)
                    } else {
                        gitdirURL = current.appendingPathComponent(gitdir).standardized
                    }
                    // Walk up from gitdir to find the .git directory, then its parent is the repo root
                    var parent = gitdirURL
                    while parent.lastPathComponent != ".git" && parent.path != "/" {
                        parent = parent.deletingLastPathComponent()
                    }
                    if parent.lastPathComponent == ".git" {
                        return parent.deletingLastPathComponent().lastPathComponent
                    }
                }
                return current.lastPathComponent
            }
            current = current.deletingLastPathComponent()
        }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }

    private func extractH1Title(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { handle.closeFile() }
        let data = handle.readData(ofLength: 4096)
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("## ") {
                return String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private func extractPlanFilePaths(from content: String) -> Set<String> {
        var paths = Set<String>()
        var searchStart = content.startIndex
        let needle = "\"planFilePath\":\""

        while searchStart < content.endIndex,
              let range = content.range(of: needle, range: searchStart..<content.endIndex) {
            let valueStart = range.upperBound
            guard let endQuote = content[valueStart...].firstIndex(of: "\"") else { break }
            let path = String(content[valueStart..<endQuote])
            if !path.isEmpty {
                paths.insert(path)
            }
            searchStart = endQuote
        }

        return paths
    }
}
