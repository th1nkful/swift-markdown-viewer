#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import PlanViewerCore

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(showingSettings: $showingSettings)
        } content: {
            if let plan = appModel.selectedPlan {
                PlanMarkdownView(plan: plan)
            } else {
                ContentUnavailableView("No Plan Selected", systemImage: "doc.text")
            }
        } detail: {
            CommentsPanelView()
        }
        .navigationTitle("Planner")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appModel.reloadPlans()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    showingSettings = true
                } label: {
                    Label("Workspaces", systemImage: "folder.badge.gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            WorkspaceSettingsView()
                .environmentObject(appModel)
        }
        .alert("Error", isPresented: Binding(get: {
            appModel.errorMessage != nil
        }, set: { newValue in
            if !newValue { appModel.errorMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appModel.errorMessage ?? "")
        }
    }
}
#endif
