#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct PlanMarkdownView: View {
    @EnvironmentObject private var appModel: AppModel
    let plan: PlanDocument

    @State private var lines: [MarkdownLine] = []
    @State private var showingPromptPreview = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { line in
                            VStack(alignment: .leading, spacing: 0) {
                                MarkdownLineRow(
                                    line: line,
                                    isSelected: appModel.selectedRange?.contains(line.lineNumber) == true,
                                    hasComment: appModel.commentedLines().contains(line.lineNumber)
                                ) { extending in
                                    appModel.selectLine(line.lineNumber, extendingSelection: extending)
                                }
                                .id(line.lineNumber)

                                ForEach(appModel.inlineComments(endingAt: line.lineNumber)) { comment in
                                    CommentCard(comment: comment, onDelete: { appModel.deleteComment(id: comment.id) })
                                        .padding(.leading, 78)
                                        .padding(.trailing, 16)
                                        .padding(.bottom, 8)
                                }

                                if appModel.selectedRange?.upperBound == line.lineNumber {
                                    InlineCommentComposer(range: appModel.selectedRange, draft: $appModel.inlineCommentDraft) {
                                        appModel.addInlineComment()
                                    }
                                    .padding(.leading, 78)
                                    .padding(.trailing, 16)
                                    .padding(.bottom, 10)
                                }
                            }
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .safeAreaInset(edge: .bottom) {
                    fileFeedbackBar
                }
                .onAppear {
                    loadLines()
                    if let line = appModel.selectedRange?.lowerBound {
                        proxy.scrollTo(line, anchor: .center)
                    }
                }
                .onChange(of: plan.id) { _, _ in
                    loadLines()
                }
            }
        }
        .sheet(isPresented: $showingPromptPreview) {
            PromptPreviewSheet(prompt: appModel.promptPreview())
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.displayName)
                    .font(.title2.weight(.semibold))
                Text(plan.workspaceName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let range = appModel.selectedRange {
                Label(
                    range.lowerBound == range.upperBound
                        ? "Selected L\(range.lowerBound)"
                        : "Selected L\(range.lowerBound)-L\(range.upperBound)",
                    systemImage: "text.line.first.and.arrowtriangle.forward"
                )
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
            }
        }
        .padding(16)
    }

    private var fileFeedbackBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("File feedback")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                CopyPromptButton(canCopy: hasAnyFeedback, onCopy: {
                    appModel.copyPrompt()
                }, onPreview: {
                    showingPromptPreview = true
                })
            }
            TextEditor(text: $appModel.fileCommentDraft)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
        }
        .padding(12)
        .glassBackground()
        .onChange(of: appModel.fileCommentDraft) { _, _ in
            saveTask?.cancel()
            saveTask = Task {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                appModel.persistFileComment()
            }
        }
    }

    private var hasAnyFeedback: Bool {
        !appModel.fileCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        appModel.comments.contains(where: { if case .lineRange = $0.anchor { return true }; return false })
    }

    private func loadLines() {
        let plan = self.plan
        Task.detached(priority: .userInitiated) {
            let parsedLines: [MarkdownLine]
            do {
                let contents = try plan.loadContents()
                parsedLines = MarkdownLineParser().parse(contents)
            } catch {
                parsedLines = []
            }
            await MainActor.run {
                lines = parsedLines
            }
        }
    }
}

// MARK: - Line Row

private struct MarkdownLineRow: View {
    let line: MarkdownLine
    let isSelected: Bool
    let hasComment: Bool
    let onSelect: (_ extendingSelection: Bool) -> Void

    var body: some View {
        Button {
            onSelect(NSEvent.modifierFlags.contains(.shift))
        } label: {
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 6) {
                    Text("\(line.lineNumber)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                    Circle()
                        .fill(hasComment ? Color.orange : Color.clear)
                        .frame(width: 7, height: 7)
                }
                .frame(width: 64, alignment: .trailing)
                .padding(.top, 6)
                .padding(.trailing, 10)
                .background(Color(nsColor: .controlBackgroundColor))

                lineContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            }
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var lineContent: some View {
        switch line.kind {
        case .empty:
            Text(" ")
                .frame(height: 20)
        case .divider:
            Divider().padding(.vertical, 8)
        case .heading(let level, let text):
            renderedText(text)
                .font(font(forHeadingLevel: level))
        case .paragraph(let text):
            renderedText(text)
        case .blockquote(let text):
            HStack(spacing: 10) {
                Rectangle().fill(Color.accentColor).frame(width: 3)
                renderedText(text).foregroundStyle(.secondary)
            }
        case .bullet(let text, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bulletSymbol(for: checked))
                    .font(.body.weight(.semibold))
                renderedText(text)
            }
        case .ordered(let index, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index).")
                    .font(.body.weight(.semibold))
                renderedText(text)
            }
        case .codeFence(let language):
            Text(language.map { "Code block (\($0))" } ?? "Code block")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        case .code(let text):
            Text(text.isEmpty ? " " : text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func renderedText(_ fallback: String) -> Text {
        if let attributed = line.attributedContent {
            return Text(attributed)
        }
        return Text(fallback)
    }

    private func font(forHeadingLevel level: Int) -> Font {
        switch level {
        case 1: return .system(size: 28, weight: .bold)
        case 2: return .system(size: 24, weight: .semibold)
        case 3: return .system(size: 20, weight: .semibold)
        case 4: return .system(size: 17, weight: .semibold)
        default: return .headline
        }
    }

    private func bulletSymbol(for checked: Bool?) -> String {
        switch checked {
        case true: return "☑"
        case false: return "☐"
        case nil: return "•"
        }
    }
}

// MARK: - Inline Comment Composer

private struct InlineCommentComposer: View {
    let range: ClosedRange<Int>?
    @Binding var draft: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextEditor(text: $draft)
                .font(.body)
                .frame(minHeight: 50, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
            HStack {
                Spacer()
                Button("Add Comment") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var title: String {
        guard let range else { return "Inline feedback" }
        return range.lowerBound == range.upperBound ? "Inline feedback for L\(range.lowerBound)" : "Inline feedback for L\(range.lowerBound)-L\(range.upperBound)"
    }
}

// MARK: - Comment Card

private struct CommentCard: View {
    let comment: PlanComment
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Text(comment.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var title: String {
        switch comment.anchor {
        case .file:
            return "File feedback"
        case .lineRange(let start, let end):
            return start == end ? "Line \(start)" : "Lines \(start)-\(end)"
        }
    }
}

// MARK: - Copy Button

private struct CopyPromptButton: View {
    let canCopy: Bool
    let onCopy: () -> Void
    let onPreview: () -> Void

    var body: some View {
        Menu {
            Button("Copy Prompt") { onCopy() }
            Button("Preview Prompt") { onPreview() }
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        } primaryAction: {
            onCopy()
        }
        .menuStyle(.button)
        .buttonStyle(.borderedProminent)
        .disabled(!canCopy)
    }
}

// MARK: - Glass Background

private struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 12))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

private extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}

// MARK: - Prompt Preview

private struct PromptPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Prompt Preview")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                Text(prompt.isEmpty ? "No feedback yet." : prompt)
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
        .padding(20)
        .frame(minWidth: 640, minHeight: 420)
    }
}
#endif
