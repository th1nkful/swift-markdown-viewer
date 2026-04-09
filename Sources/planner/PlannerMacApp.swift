#if canImport(AppKit) && canImport(SwiftUI)
import AppKit
import SwiftUI
import PlanViewerCore

private enum PlannerWindowSize {
    static let settingsWidth: CGFloat = 520
    static let settingsHeight: CGFloat = 360
}

@main
struct PlannerMacApp: App {
    @StateObject private var appModel = AppModel(startupArgument: PlannerLaunchArgument.current)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .frame(minWidth: 1200, minHeight: 760)
        }

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
