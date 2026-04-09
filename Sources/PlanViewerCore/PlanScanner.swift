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

    public func defaultWorkspaceTargets(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())) -> [WorkspaceTarget] {
        [WorkspaceTarget(name: "~/.claude/plans", url: homeDirectory.appendingPathComponent(".claude/plans", isDirectory: true))]
    }

    public func workspaceTargets(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()), configuration: WorkspaceConfiguration) -> [WorkspaceTarget] {
        let defaults = defaultWorkspaceTargets(homeDirectory: homeDirectory)
        let extras = configuration.extraDirectories.flatMap { directory in
            [WorkspaceTarget(name: directory.name, url: directory.url)] + nestedClaudeTargets(in: directory)
        }
        return dedupe(defaults + extras)
    }

    public func scan(homeDirectory: URL = URL(fileURLWithPath: NSHomeDirectory()), configuration: WorkspaceConfiguration) -> [PlanDocument] {
        workspaceTargets(homeDirectory: homeDirectory, configuration: configuration).flatMap(scanWorkspace)
            .sorted { lhs, rhs in
                lhs.modifiedAt == rhs.modifiedAt ? lhs.url.path < rhs.url.path : lhs.modifiedAt > rhs.modifiedAt
            }
    }

    public func scanWorkspace(_ target: WorkspaceTarget) -> [PlanDocument] {
        guard FileManager.default.fileExists(atPath: target.url.path) else { return [] }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(at: target.url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            return []
        }

        var plans: [PlanDocument] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            let values = try? fileURL.resourceValues(forKeys: keys)
            guard values?.isRegularFile == true else { continue }
            plans.append(PlanDocument(
                url: fileURL,
                workspaceName: target.name,
                workspaceURL: target.url,
                modifiedAt: values?.contentModificationDate ?? .distantPast
            ))
        }

        return dedupe(plans)
    }

    private func dedupe(_ targets: [WorkspaceTarget]) -> [WorkspaceTarget] {
        var seen = Set<String>()
        return targets.filter { seen.insert($0.url.standardizedFileURL.path).inserted }
    }

    private func dedupe(_ documents: [PlanDocument]) -> [PlanDocument] {
        var seen = Set<String>()
        return documents.filter { seen.insert($0.url.standardizedFileURL.path).inserted }
    }

    private func nestedClaudeTargets(in directory: WorkspaceDirectory) -> [WorkspaceTarget] {
        guard FileManager.default.fileExists(atPath: directory.url.path) else { return [] }

        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory.url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var targets: [WorkspaceTarget] = []
        for case let candidateURL as URL in enumerator {
            guard candidateURL.lastPathComponent == ".claude" else { continue }

            let plansURL = candidateURL.appendingPathComponent("plans", isDirectory: true)
            let values = try? plansURL.resourceValues(forKeys: keys)
            guard values?.isDirectory == true else {
                enumerator.skipDescendants()
                continue
            }

            let worktreeName = candidateURL.deletingLastPathComponent().lastPathComponent
            let targetName = worktreeName == directory.name ? directory.name : "\(directory.name) / \(worktreeName)"
            targets.append(WorkspaceTarget(name: targetName, url: plansURL))
            enumerator.skipDescendants()
        }

        return dedupe(targets)
    }
}
