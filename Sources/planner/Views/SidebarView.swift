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

    private var selectionBinding: Binding<PlanDocument.ID?> {
        Binding(get: {
            appModel.selectedPlan?.id
        }, set: { newValue in
            let plan = appModel.plans.first(where: { $0.id == newValue })
            appModel.selectPlan(plan)
        })
    }

    var body: some View {
        List(selection: selectionBinding) {
            ForEach(groupedPlans, id: \.0) { workspaceName, plans in
                Section(workspaceName) {
                    ForEach(plans) { plan in
                        SidebarRowView(plan: plan)
                    }
                }
            }
        }
        .overlay {
            if appModel.plans.isEmpty {
                ContentUnavailableView(
                    "No Plans Found",
                    systemImage: "tray",
                    description: Text("Planner scans ~/.claude/plans and groups them by project.")
                )
            }
        }
    }
}

private struct SidebarRowView: View {
    let plan: PlanDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(plan.displayName)
                .font(.headline)
            HStack {
                Text(plan.workspaceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(plan.modifiedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
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
#endif
