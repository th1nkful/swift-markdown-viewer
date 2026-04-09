#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct PlanMarkdownView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.theme) private var theme: AppTheme
    let plan: PlanDocument

    @State private var lines: [MarkdownLine] = []
    @State private var showingPromptPreview = false
    @State private var promptPreviewText = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var atBottom = false

    private var displayLines: [MarkdownLine] {
        var result = lines
        if plan.h1Title != nil, let first = result.first, case .heading(1, _) = first.kind {
            result = Array(result.dropFirst())
        }
        while let first = result.first, case .empty = first.kind {
            result = Array(result.dropFirst())
        }
        return result
    }

    private var largeTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.h1Title ?? plan.displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(theme.text)
            if plan.h1Title != nil || plan.workspaceName != "~/.claude/plans" {
                HStack(spacing: 6) {
                    if plan.h1Title != nil {
                        Text(plan.displayName)
                            .foregroundStyle(theme.subtext1)
                    }
                    if plan.workspaceName != "~/.claude/plans" {
                        if plan.h1Title != nil {
                            Text("·").foregroundStyle(theme.subtext0)
                        }
                        Text(plan.workspaceName)
                            .foregroundStyle(theme.subtext0)
                    }
                }
                .font(.subheadline)
            }
        }
        .padding(.leading, 76)
        .padding(.trailing, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .onAppear { appModel.showCompactTitle = false }
        .onDisappear { appModel.showCompactTitle = true }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    largeTitle

                    ForEach(displayLines) { line in
                        VStack(alignment: .leading, spacing: 0) {
                            MarkdownLineRow(
                                line: line,
                                isSelected: appModel.selectedRange?.contains(line.lineNumber) == true,
                                hasComment: appModel.commentedLines().contains(line.lineNumber),
                                onBeginSelect: { lineNum in
                                    appModel.selectLine(lineNum, extendingSelection: false)
                                },
                                onExtendSelect: { lineNum in
                                    appModel.selectLine(lineNum, extendingSelection: true)
                                }
                            )
                            .id(line.lineNumber)

                            ForEach(appModel.inlineComments(endingAt: line.lineNumber)) { comment in
                                HStack {
                                    Spacer(minLength: 0)
                                    CommentCard(comment: comment, onDelete: { appModel.deleteComment(id: comment.id) })
                                        .frame(maxWidth: 680)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                            }

                            if appModel.selectedRange?.upperBound == line.lineNumber {
                                HStack {
                                    Spacer(minLength: 0)
                                    InlineCommentComposer(
                                        range: appModel.selectedRange,
                                        draft: $appModel.inlineCommentDraft,
                                        onAdd: { appModel.addInlineComment() },
                                        onDismiss: { appModel.selectedRange = nil }
                                    )
                                    .frame(maxWidth: 680)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 10)
                            }
                        }
                    }

                    Color.clear.frame(height: 1)
                        .onAppear { atBottom = true }
                        .onDisappear { atBottom = false }
                }
            }
            .background(OverlayScrollerSetter())
            .background(theme.base)
            .safeAreaInset(edge: .bottom) {
                feedbackBar
            }
            .onAppear {
                loadLines()
                if let line = appModel.selectedRange?.lowerBound {
                    proxy.scrollTo(line, anchor: .center)
                }
            }
            .onChange(of: plan.id) { _, _ in loadLines() }
        }
        .onChange(of: appModel.fileCommentDraft) { _, _ in debounceSave() }
        .sheet(isPresented: $showingPromptPreview) {
            PromptPreviewSheet(prompt: promptPreviewText)
        }
    }

    // MARK: - Feedback Content

    @ViewBuilder
    private var feedbackCore: some View {
        VStack(alignment: .trailing, spacing: 8) {
            TextEditor(text: $appModel.fileCommentDraft)
                .font(.body)
                .foregroundStyle(theme.text)
                .frame(minHeight: 60, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(theme.base, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.surface2.opacity(0.4), lineWidth: 1)
                }
            CopyPromptButton(canCopy: hasAnyFeedback, onCopy: {
                appModel.copyPrompt()
            }, onPreview: {
                promptPreviewText = appModel.promptPreview()
                showingPromptPreview = true
            })
        }
    }

    private var feedbackBar: some View {
        HStack {
            Spacer(minLength: 0)
            feedbackCore
                .frame(maxWidth: 680)
                .padding(12)
                .modifier(FeedbackBarStyle(floating: !atBottom))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var hasAnyFeedback: Bool {
        !appModel.fileCommentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        appModel.comments.contains(where: { if case .lineRange = $0.anchor { return true }; return false })
    }

    private func debounceSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            appModel.persistFileComment()
        }
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
            await MainActor.run { lines = parsedLines }
        }
    }
}

// MARK: - Line Row

private struct MarkdownLineRow: View {
    @Environment(\.theme) private var theme: AppTheme
    let line: MarkdownLine
    let isSelected: Bool
    let hasComment: Bool
    let onBeginSelect: (Int) -> Void
    let onExtendSelect: (Int) -> Void
    @State private var gutterHovered = false

    private var isCodeBlock: Bool {
        switch line.kind {
        case .code, .codeFence: return true
        default: return false
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            gutterView

            lineContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, isCodeBlock ? 0 : lineContentTopPad + 5)
                .padding(.bottom, isCodeBlock ? 0 : 5)
                .background(isSelected && !isCodeBlock ? theme.mauve.opacity(0.15) : Color.clear)
        }
        .background(rowBackground)
    }

    private var rowBackground: Color {
        if isCodeBlock { return theme.surface0.opacity(0.3) }
        if isSelected { return theme.mauve.opacity(0.08) }
        if hasComment { return theme.peach.opacity(0.08) }
        return Color.clear
    }

    private var gutterView: some View {
        HStack(spacing: 4) {
            if gutterHovered && !isCodeBlock {
                Image(systemName: "text.bubble")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.subtext1)
            } else {
                Text("\(line.lineNumber)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.surface2)
            }
            Circle()
                .fill(hasComment ? theme.peach : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(width: 56, alignment: .trailing)
        .padding(.top, isCodeBlock ? 2 : lineContentTopPad + 7)
        .padding(.trailing, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { gutterHovered = $0 }
        .overlay {
            GutterDragOverlay(
                lineNumber: line.lineNumber,
                onBegin: onBeginSelect,
                onDragToLine: onExtendSelect
            )
        }
    }

    private var lineContentTopPad: CGFloat {
        switch line.kind {
        case .heading(1, _): return 24
        case .heading(2, _): return 18
        case .heading(3, _): return 14
        case .heading(_, _): return 10
        default: return 0
        }
    }

    @ViewBuilder
    private var lineContent: some View {
        switch line.kind {
        case .empty:
            Color.clear.frame(height: 14)

        case .divider:
            Rectangle().fill(theme.surface0).frame(height: 1).padding(.vertical, 10)

        case .heading(let level, let text):
            renderedText(text)
                .font(font(forHeadingLevel: level))
                .foregroundStyle(theme.text)
                .padding(.bottom, level <= 2 ? 4 : 2)

        case .paragraph(let text):
            renderedText(text)
                .font(.system(size: 14))
                .foregroundStyle(theme.text)
                .lineSpacing(3)

        case .blockquote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(theme.surface2)
                    .frame(width: 3)
                renderedText(text)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.subtext1)
                    .italic()
            }

        case .bullet(let text, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bulletSymbol(for: checked))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(checked == true ? theme.subtext0 : theme.text)
                renderedText(text)
                    .font(.system(size: 14))
                    .strikethrough(checked == true)
                    .foregroundStyle(checked == true ? theme.subtext0 : theme.text)
            }

        case .ordered(let index, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(theme.text)
                    .monospacedDigit()
                renderedText(text)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.text)
            }

        case .codeFence(let language):
            if let language, !language.isEmpty {
                Text(language)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.subtext0)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
            } else {
                Spacer().frame(height: 4)
            }

        case .code(let text):
            Text(text.isEmpty ? " " : text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 1)

        case .table(let cells, let isHeader):
            HStack(spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { i, cell in
                    Text(cell)
                        .font(.system(size: 13, weight: isHeader ? .semibold : .regular))
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                    if i < cells.count - 1 {
                        Rectangle().fill(theme.surface0).frame(width: 1)
                    }
                }
            }
            .background(isHeader ? theme.surface0.opacity(0.3) : Color.clear)

        case .tableSeparator:
            Rectangle().fill(theme.surface0).frame(height: 1).padding(.horizontal, 4)
        }
    }

    private func renderedText(_ fallback: String) -> Text {
        if let attributed = line.attributedContent { return Text(attributed) }
        return Text(fallback)
    }

    private func font(forHeadingLevel level: Int) -> Font {
        switch level {
        case 1: return .system(size: 26, weight: .bold)
        case 2: return .system(size: 21, weight: .semibold)
        case 3: return .system(size: 17, weight: .semibold)
        case 4: return .system(size: 15, weight: .semibold)
        default: return .system(size: 14, weight: .semibold)
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

// MARK: - Overlay Scroller

private struct OverlayScrollerSetter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { applyOverlayStyle(from: view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func applyOverlayStyle(from view: NSView) {
        var current: NSView? = view
        while let v = current {
            if let scrollView = v as? NSScrollView {
                scrollView.scrollerStyle = .overlay
                return
            }
            current = v.superview
        }
    }
}

// MARK: - Gutter Drag (NSViewRepresentable for reliable mouseDown/Drag)

private struct GutterDragOverlay: NSViewRepresentable {
    let lineNumber: Int
    let onBegin: (Int) -> Void
    let onDragToLine: (Int) -> Void

    func makeNSView(context: Context) -> GutterNSView {
        GutterNSView(lineNumber: lineNumber, onBegin: onBegin, onDragToLine: onDragToLine)
    }

    func updateNSView(_ nsView: GutterNSView, context: Context) {
        nsView.lineNumber = lineNumber
        nsView.onBegin = onBegin
        nsView.onDragToLine = onDragToLine
    }

    class GutterNSView: NSView {
        var lineNumber: Int
        var onBegin: (Int) -> Void
        var onDragToLine: (Int) -> Void
        private var dragStartY: CGFloat = 0
        private static let estimatedRowHeight: CGFloat = 28

        init(lineNumber: Int, onBegin: @escaping (Int) -> Void, onDragToLine: @escaping (Int) -> Void) {
            self.lineNumber = lineNumber
            self.onBegin = onBegin
            self.onDragToLine = onDragToLine
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            dragStartY = event.locationInWindow.y
            onBegin(lineNumber)
        }

        override func mouseDragged(with event: NSEvent) {
            let deltaY = dragStartY - event.locationInWindow.y
            let linesDelta = Int(round(deltaY / Self.estimatedRowHeight))
            onDragToLine(max(1, lineNumber + linesDelta))
        }
    }
}

// MARK: - Inline Comment Composer

private struct InlineCommentComposer: View {
    @Environment(\.theme) private var theme: AppTheme
    let range: ClosedRange<Int>?
    @Binding var draft: String
    let onAdd: () -> Void
    let onDismiss: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.text)
            TextEditor(text: $draft)
                .font(.system(size: 14))
                .foregroundStyle(theme.text)
                .focused($isFocused)
                .frame(minHeight: 50, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(theme.base, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.surface2.opacity(0.4), lineWidth: 1)
                }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { onDismiss() }
                    .buttonStyle(.bordered)
                Button("Add Comment") { onAdd() }
                    .themedProminentButton()
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .themedGlassBackground()
        .onAppear {
            DispatchQueue.main.async { isFocused = true }
        }
        .onKeyPress(.escape) {
            if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                onDismiss()
            } else {
                draft = ""
            }
            return .handled
        }
    }

    private var title: String {
        guard let range else { return "Inline feedback" }
        return range.lowerBound == range.upperBound
            ? "Inline feedback for L\(range.lowerBound)"
            : "Inline feedback for L\(range.lowerBound)-L\(range.upperBound)"
    }
}

// MARK: - Comment Card

private struct CommentCard: View {
    @Environment(\.theme) private var theme: AppTheme
    let comment: PlanComment
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.subtext1)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").font(.caption)
                }
                .buttonStyle(.borderless)
            }
            Text(comment.text)
                .font(.system(size: 14))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .themedGlassBackground()
    }

    private var title: String {
        switch comment.anchor {
        case .file: return "File"
        case .lineRange(let start, let end):
            return start == end ? "L\(start)" : "L\(start)-L\(end)"
        }
    }
}

// MARK: - Copy Button

private struct CopyPromptButton: View {
    @Environment(\.theme) private var theme: AppTheme
    let canCopy: Bool
    let onCopy: () -> Void
    let onPreview: () -> Void

    private var bg: Color { theme.isSystem ? .accentColor : theme.mauve }
    private var fg: Color { theme.isSystem ? .white : theme.crust }

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Divider()
                .frame(height: 16)
                .overlay(fg.opacity(0.3))

            Menu {
                Button("Copy Prompt") { onCopy() }
                Button("Preview Prompt") { onPreview() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
        .foregroundStyle(canCopy ? fg : fg.opacity(0.5))
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(canCopy ? bg : bg.opacity(0.4))
        )
        .disabled(!canCopy)
    }
}

// MARK: - Themed Button

private struct ThemedProminentButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme: AppTheme
    @Environment(\.isEnabled) private var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(theme.isSystem ? Color.white : theme.crust)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.mauve.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1.0) : 0.4))
            )
    }
}

private struct ThemedProminentButtonModifier: ViewModifier {
    @Environment(\.theme) private var theme: AppTheme

    func body(content: Content) -> some View {
        if theme.isSystem {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(ThemedProminentButtonStyle())
        }
    }
}

private extension View {
    func themedProminentButton() -> some View {
        modifier(ThemedProminentButtonModifier())
    }
}

// MARK: - Glass Background

private struct FeedbackBarStyle: ViewModifier {
    @Environment(\.theme) private var theme: AppTheme
    let floating: Bool

    func body(content: Content) -> some View {
        if floating {
            content.themedGlassBackground()
        } else {
            content
                .background(theme.mantle, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.surface0.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

private struct ThemedGlassBackground: ViewModifier {
    @Environment(\.theme) private var theme: AppTheme

    func body(content: Content) -> some View {
        if theme.isSystem {
            if #available(macOS 26.0, *) {
                content.glassEffect(.regular, in: .rect(cornerRadius: 12))
            } else {
                content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        } else {
            content
                .background(theme.mantle, in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.surface0.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

private extension View {
    func themedGlassBackground() -> some View {
        modifier(ThemedGlassBackground())
    }
}

// MARK: - Prompt Preview

private struct PromptPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme: AppTheme
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Prompt Preview")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.text)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            ScrollView {
                Text(prompt.isEmpty ? "No feedback yet." : prompt)
                    .textSelection(.enabled)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .background(theme.base, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.surface2.opacity(0.4), lineWidth: 1)
            }
        }
        .padding(20)
        .background(theme.mantle)
        .frame(minWidth: 640, minHeight: 420)
    }
}
#endif
