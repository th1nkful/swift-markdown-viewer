#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct SidebarView: View {
    @EnvironmentObject private var appModel: AppModel
    @Binding var showingSettings: Bool

    private var groupedPlans: [(String, [PlanDocument])] {
        Dictionary(grouping: appModel.plans, by: \.workspaceName)
            .map { ($0.key, $0.value.sorted { $0.modifiedAt > $1.modifiedAt }) }
            .sorted { $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending }
    }

    var body: some View {
        List(selection: Binding(get: {
            appModel.selectedPlan?.id
        }, set: { newValue in
            let plan = appModel.plans.first(where: { $0.id == newValue })
            appModel.selectPlan(plan)
        })) {
            ForEach(groupedPlans, id: \.0) { workspaceName, plans in
                Section(workspaceName) {
                    ForEach(plans) { plan in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.displayName)
                                .font(.headline)
                            Text(plan.pathDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .tag(plan.id)
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([plan.url])
                            }
                            Button("Copy Path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(plan.url.path, forType: .string)
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if appModel.plans.isEmpty {
                ContentUnavailableView("No Plans Found", systemImage: "tray") {
                    Text("Planner scans ~/.claude/plans and your configured workspace directories.")
                }
            }
        }
    }
}
#endif
