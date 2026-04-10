#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

struct SidebarView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.theme) private var theme: AppTheme
    @Binding var showingSettings: Bool

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
            ForEach(appModel.plans) { plan in
                SidebarRowView(plan: plan)
                    .listRowBackground(theme.isSystem ? nil : theme.mantle)
            }
        }
        .scrollContentBackground(theme.isSystem ? .automatic : .hidden)
        .background(theme.isSystem ? Color.clear : theme.mantle)
        .background(WindowAppearanceSetter(isSystem: theme.isSystem, isDark: theme.isDark, backgroundColor: NSColor(theme.crust)))
        .overlay {
            if appModel.plans.isEmpty {
                ContentUnavailableView(
                    "No Plans Found",
                    systemImage: "tray",
                    description: Text("No plans found in ~/.claude/plans")
                )
            }
        }
    }
}

private struct SidebarRowView: View {
    @Environment(\.theme) private var theme: AppTheme
    let plan: PlanDocument

    private var showProject: Bool {
        plan.workspaceName != "~/.claude/plans"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(plan.h1Title ?? plan.displayName)
                .font(.headline)
                .foregroundStyle(theme.text)
                .lineLimit(1)
            HStack {
                if showProject {
                    Text(plan.workspaceName)
                        .font(.caption)
                        .foregroundStyle(theme.subtext1)
                        .lineLimit(1)
                }
                Spacer()
                Text(relativeTime(from: plan.modifiedAt))
                    .font(.caption)
                    .foregroundStyle(theme.subtext0)
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

private class AppearanceView: NSView {
    var applyAppearance: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { applyAppearance?(window) }
    }
}

private struct WindowAppearanceSetter: NSViewRepresentable {
    let isSystem: Bool
    let isDark: Bool
    let backgroundColor: NSColor

    func makeNSView(context: Context) -> AppearanceView {
        let view = AppearanceView()
        view.applyAppearance = { [isSystem, isDark, backgroundColor] window in
            Self.applyTo(window: window, isSystem: isSystem, isDark: isDark, backgroundColor: backgroundColor)
        }
        return view
    }

    func updateNSView(_ nsView: AppearanceView, context: Context) {
        nsView.applyAppearance = { [isSystem, isDark, backgroundColor] window in
            Self.applyTo(window: window, isSystem: isSystem, isDark: isDark, backgroundColor: backgroundColor)
        }
        if let window = nsView.window {
            DispatchQueue.main.async {
                Self.applyTo(window: window, isSystem: isSystem, isDark: isDark, backgroundColor: backgroundColor)
            }
        }
    }

    private static func applyTo(window: NSWindow, isSystem: Bool, isDark: Bool, backgroundColor: NSColor) {
        if isSystem {
            window.appearance = nil
            window.backgroundColor = nil
        } else {
            window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
            window.backgroundColor = backgroundColor
        }
    }
}

private func relativeTime(from date: Date) -> String {
    let seconds = Date().timeIntervalSince(date)
    let hours = Int(seconds / 3600)
    if hours < 1 { return "less than an hour" }
    if hours < 24 { return hours == 1 ? "1 hour" : "\(hours) hours" }
    let days = hours / 24
    if days < 7 { return days == 1 ? "1 day" : "\(days) days" }
    let weeks = days / 7
    return weeks == 1 ? "1 week" : "\(weeks) weeks"
}
#endif
