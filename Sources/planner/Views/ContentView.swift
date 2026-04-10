#if canImport(AppKit) && canImport(SwiftUI)
import SwiftUI
import PlanViewerCore

struct ContentView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.theme) private var theme: AppTheme
    @State private var showingSettings = false

    var body: some View {
        NavigationSplitView {
            SidebarView(showingSettings: $showingSettings)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 400)
        } detail: {
            if let plan = appModel.selectedPlan {
                PlanMarkdownView(plan: plan)
            } else {
                ContentUnavailableView("No Plan Selected", systemImage: "doc.text")
            }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .navigationTitle(compactTitle)
        .navigationSubtitle(compactSubtitle)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 8) {
                    Button {
                        appModel.reloadPlansAsync()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
        .toolbarBackground(theme.isSystem ? Color.clear : theme.mantle, for: .windowToolbar)
        .tint(theme.isSystem ? nil : theme.mauve)
        .sheet(isPresented: $showingSettings) {
            WorkspaceSettingsView()
                .environmentObject(appModel)
                .environment(\.theme, theme)
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

    private var compactTitle: String {
        guard appModel.showCompactTitle, let plan = appModel.selectedPlan else { return "" }
        return plan.h1Title ?? plan.displayName
    }

    private var compactSubtitle: String {
        guard appModel.showCompactTitle, let plan = appModel.selectedPlan, plan.h1Title != nil else { return "" }
        return plan.displayName
    }
}
#endif
