#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

private struct PlannerWindowSize {
    static let settingsWidth: CGFloat = 520
    static let settingsHeight: CGFloat = 480

    private init() {}
}

@main
struct PlannerMacApp: App {
    @StateObject private var appModel = AppModel(startupArgument: PlannerLaunchArgument.current)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .environment(\.theme, appModel.selectedTheme)
                .preferredColorScheme(appModel.selectedTheme.isSystem ? nil : (appModel.selectedTheme.isDark ? .dark : .light))
                .frame(minWidth: 1200, minHeight: 760)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowToolbarStyle(.unified(showsTitle: true))

        Settings {
            WorkspaceSettingsView()
                .environmentObject(appModel)
                .frame(width: PlannerWindowSize.settingsWidth, height: PlannerWindowSize.settingsHeight)
        }
    }
}

struct PlannerLaunchArgument {
    let fileURL: URL?

    static var current: PlannerLaunchArgument {
        guard CommandLine.arguments.count > 1 else { return PlannerLaunchArgument(fileURL: nil) }
        let rawValue = (CommandLine.arguments[1] as NSString).expandingTildeInPath
        return PlannerLaunchArgument(fileURL: URL(fileURLWithPath: rawValue))
    }
}
#endif
