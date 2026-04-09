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
            nestedClaudeTargets(in: directory)
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
        let keys: Set<URLResourceKey> = [.isDirectoryKey]
        var targets: [WorkspaceTarget] = []

        // Case 1: the added directory itself is a worktree that has .claude/plans
        let directPlansURL = directory.url
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("plans", isDirectory: true)
        if let values = try? directPlansURL.resourceValues(forKeys: keys), values.isDirectory == true {
            targets.append(WorkspaceTarget(name: directory.name, url: directPlansURL))
        }

        // Case 2: the added directory is a parent containing multiple worktrees
        guard let childURLs = try? FileManager.default.contentsOfDirectory(
            at: directory.url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else {
            return targets
        }

        for childURL in childURLs {
            let childValues = try? childURL.resourceValues(forKeys: keys)
            guard childValues?.isDirectory == true else { continue }

            let plansURL = childURL
                .appendingPathComponent(".claude", isDirectory: true)
                .appendingPathComponent("plans", isDirectory: true)
            let plansValues = try? plansURL.resourceValues(forKeys: keys)
            guard plansValues?.isDirectory == true else { continue }

            let worktreeName = childURL.lastPathComponent
            targets.append(WorkspaceTarget(name: "\(directory.name) / \(worktreeName)", url: plansURL))
        }

        return dedupe(targets)
    }
}
