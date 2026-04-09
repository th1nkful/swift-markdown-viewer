#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct PlanMarkdownView: View {
    @EnvironmentObject private var appModel: AppModel
    let plan: PlanDocument

    @State private var lines: [MarkdownLine] = []
    private let parser = MarkdownLineParser()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(lines) { line in
                            MarkdownLineRow(
                                line: line,
                                isSelected: appModel.selectedRange?.contains(line.lineNumber) == true,
                                hasComment: appModel.commentedLines().contains(line.lineNumber)
                            ) {
                                select(lineNumber: line.lineNumber)
                            }
                            .id(line.lineNumber)
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName)
                        .font(.title2.weight(.semibold))
                    Text(plan.pathDisplay)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Workspace: \(plan.workspaceName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let range = appModel.selectedRange {
                    Label(range.lowerBound == range.upperBound ? "Selected L\(range.lowerBound)" : "Selected L\(range.lowerBound)-L\(range.upperBound)", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: Capsule())
                }
            }

            if appModel.selectedRange != nil {
                HStack(spacing: 12) {
                    TextField("Inline feedback for selected lines", text: $appModel.inlineCommentDraft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Add Inline Comment") {
                        appModel.addInlineComment()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(16)
    }

    private func loadLines() {
        let contents = (try? plan.loadContents()) ?? ""
        lines = parser.parse(contents)
    }

    private func select(lineNumber: Int) {
        if let current = appModel.selectedRange,
           NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
            let start = min(current.lowerBound, lineNumber)
            let end = max(current.lowerBound, lineNumber)
            appModel.selectedRange = start...end
        } else {
            appModel.selectedRange = lineNumber...lineNumber
        }
    }
}

private struct MarkdownLineRow: View {
    let line: MarkdownLine
    let isSelected: Bool
    let hasComment: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button(action: onSelect) {
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
            }
            .buttonStyle(.plain)
            .background(Color(nsColor: .controlBackgroundColor))

            lineContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        }
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
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
            inlineText(text)
                .font(font(forHeadingLevel: level))
        case .paragraph(let text):
            inlineText(text)
        case .blockquote(let text):
            HStack(spacing: 10) {
                Rectangle().fill(Color.accentColor).frame(width: 3)
                inlineText(text).foregroundStyle(.secondary)
            }
        case .bullet(let text, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bulletSymbol(for: checked))
                    .font(.body.weight(.semibold))
                inlineText(text)
            }
        case .ordered(let index, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(index).")
                    .font(.body.weight(.semibold))
                inlineText(text)
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

    private func inlineText(_ source: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(source)
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
#endif
