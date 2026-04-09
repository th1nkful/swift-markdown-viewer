#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct CommentsPanelView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Feedback")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Copy Prompt") {
                    appModel.copyPrompt()
                }
                .buttonStyle(.borderedProminent)
                .disabled(appModel.comments.isEmpty)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("File-level feedback")
                    .font(.headline)
                TextField("Overall feedback for this plan", text: $appModel.fileCommentDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Add File Comment") {
                    appModel.addFileComment()
                }
                .buttonStyle(.bordered)
            }

            if let range = appModel.selectedRange {
                VStack(alignment: .leading, spacing: 8) {
                    Text(range.lowerBound == range.upperBound ? "Inline feedback for L\(range.lowerBound)" : "Inline feedback for L\(range.lowerBound)-L\(range.upperBound)")
                        .font(.headline)
                    Text("Use the left gutter in the plan view to select a single line or shift-click a range.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            List {
                ForEach(Array(appModel.comments.enumerated()), id: \.element.id) { index, comment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title(for: comment))
                            .font(.subheadline.weight(.semibold))
                        Text(comment.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .tag(index)
                }
                .onDelete(perform: appModel.deleteComments)
            }
            .listStyle(.inset)

            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt preview")
                    .font(.headline)
                ScrollView {
                    Text(appModel.promptPreview().isEmpty ? "No feedback yet." : appModel.promptPreview())
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
        }
        .padding(16)
    }

    private func title(for comment: PlanComment) -> String {
        switch comment.anchor {
        case .file:
            return "File feedback"
        case .lineRange(let start, let end):
            return start == end ? "Line \(start)" : "Lines \(start)-\(end)"
        }
    }
}
#endif
