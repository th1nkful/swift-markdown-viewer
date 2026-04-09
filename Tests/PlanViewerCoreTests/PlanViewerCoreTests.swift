import Foundation
import Testing
@testable import PlanViewerCore

@Test func promptBuilderFormatsFileAndInlineComments() {
    let builder = PlanPromptBuilder()
    let comments: [PlanComment] = [
        PlanComment(anchor: .file, text: "Top-level issue."),
        PlanComment(anchor: .lineRange(start: 10, end: 12), text: "Tighten this section."),
        PlanComment(anchor: .lineRange(start: 4, end: 4), text: "Clarify the title.")
    ]

    let prompt = builder.buildPrompt(for: comments)

    #expect(prompt.contains("Here is feedback on the plan:"))
    #expect(prompt.contains("Top-level issue."))
    #expect(prompt.contains("Around L4: Clarify the title."))
    #expect(prompt.contains("Around L10 to L12: Tighten this section."))
}

@Test func promptBuilderUsesCustomTemplatePlaceholders() {
    let builder = PlanPromptBuilder()
    let comments: [PlanComment] = [
        PlanComment(anchor: .file, text: "Top-level issue."),
        PlanComment(anchor: .lineRange(start: 4, end: 4), text: "Clarify the title.")
    ]

    let prompt = builder.buildPrompt(
        for: comments,
        template: "Summary\n{{file_comments}}\n\nInline\n{{inline_comments}}"
    )

    #expect(prompt == "Summary\nTop-level issue.\n\nInline\nAround L4: Clarify the title.")
}

@Test func markdownParserTracksHeadingsListsAndCode() {
    let parser = MarkdownLineParser()
    let lines = parser.parse("# Title\n- [x] done\n```swift\nlet x = 1\n```\n> note")

    #expect(lines.count == 6)
    #expect(lines[0].kind == .heading(level: 1, text: "Title"))
    #expect(lines[1].kind == .bullet(text: "done", checked: true))
    #expect(lines[2].kind == .codeFence(language: "swift"))
    #expect(lines[3].kind == .code(text: "let x = 1"))
    #expect(lines[5].kind == .blockquote(text: "note"))
}

@Test func planScannerFindsMarkdownRecursively() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let plansRoot = root.appendingPathComponent("plans", isDirectory: true)
    let nested = plansRoot.appendingPathComponent("worktree", isDirectory: true)
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    try "# A".write(to: plansRoot.appendingPathComponent("alpha.md"), atomically: true, encoding: .utf8)
    try "# B".write(to: nested.appendingPathComponent("beta.md"), atomically: true, encoding: .utf8)
    try "ignore".write(to: nested.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

    let scanner = PlanScanner()
    let documents = scanner.scanWorkspace(.init(name: "Plans", url: plansRoot))

    #expect(documents.count == 2)
    #expect(Set(documents.map(\.displayName)) == ["alpha", "beta"])
}

@Test func commentStorePersistsPerPlan() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = CommentStore(fileURL: root.appendingPathComponent("comments.json"))

    let saved = [PlanComment(anchor: .file, text: "Saved")]
    try store.saveComments(saved, for: "/tmp/plan.md")

    let loaded = store.loadComments(for: "/tmp/plan.md")
    #expect(loaded == saved)
}

@Test func workspaceStoreRoundTripsDirectories() throws {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = WorkspaceStore(fileURL: root.appendingPathComponent("workspaces.json"))
    let configuration = WorkspaceConfiguration(extraDirectories: [
        WorkspaceDirectory(name: "Repo", path: "~/code/repo"),
        WorkspaceDirectory(name: "Worktree", path: "~/code/repo-worktree")
    ], promptTemplate: "{{file_comments_section}}")

    try store.save(configuration)
    let loaded = store.load()

    #expect(loaded == configuration)
}
