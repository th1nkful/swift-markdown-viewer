#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import Foundation
import SwiftUI
import PlanViewerCore

@MainActor
final class AppModel: ObservableObject {
    @Published var workspaceConfiguration: WorkspaceConfiguration
    @Published var plans: [PlanDocument] = []
    @Published var selectedPlan: PlanDocument?
    @Published var comments: [PlanComment] = []
    @Published var selectedRange: ClosedRange<Int>?
    @Published var fileCommentDraft = ""
    @Published var inlineCommentDraft = ""
    @Published var errorMessage: String?
    @Published var showCompactTitle = false
    @Published var selectedTheme: AppTheme {
        didSet { UserDefaults.standard.set(selectedTheme.id, forKey: "selectedThemeID") }
    }

    private let scanner = PlanScanner()
    private let promptBuilder = PlanPromptBuilder()
    private let workspaceStore: WorkspaceStore
    private let commentStore: CommentStore
    private let startupArgument: PlannerLaunchArgument
    private(set) var selectionAnchorLine: Int?

    init(startupArgument: PlannerLaunchArgument) {
        self.startupArgument = startupArgument
        let supportDirectory = AppModel.applicationSupportDirectory()
        self.workspaceStore = WorkspaceStore(fileURL: supportDirectory.appendingPathComponent("workspaces.json"))
        self.commentStore = CommentStore(fileURL: supportDirectory.appendingPathComponent("comments.json"))
        self.workspaceConfiguration = workspaceStore.load()
        let savedID = UserDefaults.standard.string(forKey: "selectedThemeID") ?? "system"
        self.selectedTheme = AppTheme.allThemes.first { $0.id == savedID } ?? .system
        reloadPlans(selecting: startupArgument.fileURL)
    }

    func reloadPlans(selecting preferredURL: URL? = nil) {
        let scannedPlans = scanner.scan()
        applyScannedPlans(scannedPlans, selecting: preferredURL)
    }

    func reloadPlansAsync() {
        let scanner = self.scanner
        Task.detached(priority: .userInitiated) {
            let scannedPlans = scanner.scan()
            await MainActor.run { self.applyScannedPlans(scannedPlans) }
        }
    }

    private func applyScannedPlans(_ scannedPlans: [PlanDocument], selecting preferredURL: URL? = nil) {
        plans = scannedPlans

        if let preferredURL {
            let standardized = preferredURL.standardizedFileURL
            if let existing = plans.first(where: { $0.url.standardizedFileURL == standardized }) {
                selectPlan(existing)
                return
            }
            if FileManager.default.fileExists(atPath: standardized.path) {
                let document = PlanDocument(url: standardized, workspaceName: standardized.deletingLastPathComponent().lastPathComponent, workspaceURL: standardized.deletingLastPathComponent(), modifiedAt: (try? standardized.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
                plans.insert(document, at: 0)
                selectPlan(document)
                return
            }
        }

        if let selectedPlan,
           let refreshed = plans.first(where: { $0.id == selectedPlan.id }) {
            selectPlan(refreshed)
        } else if let first = plans.first {
            selectPlan(first)
        } else {
            selectedPlan = nil
            comments = []
            selectedRange = nil
            fileCommentDraft = ""
        }
    }

    func selectPlan(_ plan: PlanDocument?) {
        if let currentPlan = selectedPlan {
            syncFileComment()
            persistComments(for: currentPlan)
        }

        selectedPlan = plan
        selectedRange = nil
        selectionAnchorLine = nil
        inlineCommentDraft = ""
        guard let plan else {
            comments = []
            fileCommentDraft = ""
            return
        }
        comments = commentStore.loadComments(for: plan.url.path)
        fileCommentDraft = comments
            .compactMap { if case .file = $0.anchor { return $0.text } else { return nil } }
            .joined(separator: "\n\n")
    }

    func addInlineComment() {
        guard let plan = selectedPlan, let range = selectedRange else { return }
        let trimmed = inlineCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        comments.append(PlanComment(anchor: .lineRange(start: range.lowerBound, end: range.upperBound), text: trimmed))
        persistComments(for: plan)
        inlineCommentDraft = ""
        selectedRange = nil
        selectionAnchorLine = nil
    }

    func deleteComments(at offsets: IndexSet) {
        guard let plan = selectedPlan else { return }
        comments.remove(atOffsets: offsets)
        persistComments(for: plan)
    }

    func deleteComment(id: UUID) {
        guard let plan = selectedPlan else { return }
        comments.removeAll { $0.id == id }
        persistComments(for: plan)
    }

    func persistFileComment() {
        guard let plan = selectedPlan else { return }
        syncFileComment()
        persistComments(for: plan)
    }

    func copyPrompt() {
        syncFileComment()
        let prompt = promptBuilder.buildPrompt(for: comments, template: workspaceConfiguration.promptTemplate)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
    }

    func promptPreview() -> String {
        var effectiveComments = comments.filter { comment in
            if case .file = comment.anchor { return false }
            return true
        }
        let trimmed = fileCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            effectiveComments.append(PlanComment(anchor: .file, text: trimmed))
        }
        return promptBuilder.buildPrompt(for: effectiveComments, template: workspaceConfiguration.promptTemplate)
    }

    func updatePromptTemplate(_ template: String) {
        workspaceConfiguration.promptTemplate = template.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        persistWorkspaceConfiguration()
    }

    func resetPromptTemplate() {
        workspaceConfiguration.promptTemplate = nil
        persistWorkspaceConfiguration()
    }

    func inlineComments(endingAt lineNumber: Int) -> [PlanComment] {
        comments.filter {
            guard case .lineRange(_, let end) = $0.anchor else { return false }
            return end == lineNumber
        }
    }

    func commentedLines() -> Set<Int> {
        Set(comments.flatMap { comment -> [Int] in
            guard case .lineRange(let start, let end) = comment.anchor else { return [] }
            return Array(start...end)
        })
    }

    func selectLine(_ lineNumber: Int, extendingSelection: Bool) {
        if extendingSelection, let anchor = selectionAnchorLine {
            let start = min(anchor, lineNumber)
            let end = max(anchor, lineNumber)
            selectedRange = start...end
        } else {
            selectionAnchorLine = lineNumber
            selectedRange = lineNumber...lineNumber
        }
    }

    private func syncFileComment() {
        comments.removeAll { if case .file = $0.anchor { return true }; return false }
        let trimmed = fileCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            comments.append(PlanComment(anchor: .file, text: trimmed))
        }
    }

    private func persistWorkspaceConfiguration() {
        do {
            try workspaceStore.save(workspaceConfiguration)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func persistComments(for plan: PlanDocument) {
        do {
            try commentStore.saveComments(comments, for: plan.url.path)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func applicationSupportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = base.appendingPathComponent("planner", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
#endif
