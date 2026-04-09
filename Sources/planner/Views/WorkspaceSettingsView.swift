#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct WorkspaceSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var path = ""
    @State private var promptTemplate = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workspace Directories")
                .font(.title3.weight(.semibold))

            Text("Planner always scans ~/.claude/plans. Added repo or worktree directories also include any nested .claude/plans folders, so a parent directory can surface plans from multiple worktrees.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Display name (optional)", text: $name)
                HStack {
                    TextField("Directory path", text: $path)
                    Button("Browse…") {
                        chooseDirectory()
                    }
                }
                HStack {
                    Spacer()
                    Button("Add Directory") {
                        appModel.addWorkspace(path: path, name: name)
                        if appModel.errorMessage == nil {
                            name = ""
                            path = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
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

                TextEditor(text: Binding(get: {
                    promptTemplate
                }, set: { newValue in
                    promptTemplate = newValue
                    appModel.updatePromptTemplate(newValue)
                }))
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                }
            }

            List {
                Section("Configured Directories") {
                    ForEach(appModel.workspaceConfiguration.extraDirectories) { directory in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(directory.name)
                                .font(.headline)
                            Text(directory.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete(perform: appModel.removeWorkspaces)
                }
            }
            .listStyle(.inset)

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
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK {
            path = panel.url?.path ?? path
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = panel.url?.lastPathComponent ?? name
            }
        }
    }
}
#endif
