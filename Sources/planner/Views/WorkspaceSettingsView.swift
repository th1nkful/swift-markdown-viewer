#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct WorkspaceSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var path = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workspace Directories")
                .font(.title3.weight(.semibold))

            Text("Planner always scans ~/.claude/plans. Add repo or worktree directories here to view plans from the same workspace without opening another app window.")
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
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if panel.runModal() == .OK {
            path = panel.url?.path ?? path
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                name = panel.url?.lastPathComponent ?? name
            }
        }
    }
}
#endif
