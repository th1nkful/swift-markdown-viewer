#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import PlanViewerCore

struct WorkspaceSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var promptTemplate = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                Text("Theme")
                    .font(.headline)
                Picker("Theme", selection: $appModel.selectedTheme) {
                    ForEach(AppTheme.allThemes) { theme in
                        Text(theme.name).tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.radioGroup)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Prompt Template")
                        .font(.headline)
                    Spacer()
                    Button("Reset Default") {
                        appModel.resetPromptTemplate()
                        promptTemplate = appModel.workspaceConfiguration.promptTemplate ?? PlanPromptBuilder.defaultTemplate
                    }
                    .buttonStyle(.bordered)
                }

                Text("Use placeholders to control copied and previewed prompts: {{file_comments_section}}, {{inline_comments_section}}, {{file_comments}}, {{inline_comments}}.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $promptTemplate)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    }
            }

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .onAppear {
            promptTemplate = appModel.workspaceConfiguration.promptTemplate ?? PlanPromptBuilder.defaultTemplate
        }
        .onDisappear {
            appModel.updatePromptTemplate(promptTemplate)
        }
    }
}
#endif
