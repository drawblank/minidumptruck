import DefaultBackend
import SwiftCrossUI

/// Cross-platform GUI entry point. The in-progress portable replacement for the
/// macOS SwiftUI app: a sidebar of analysis sections + detail panes, all driven
/// by `MiniDumpTruckCore`. Backed by GTK4 on Linux / WinUI on Windows / AppKit
/// on macOS via swift-cross-ui's `DefaultBackend`.
///
/// An optional `.dmp` path on the command line opens that dump at launch;
/// otherwise use the in-app "Open .dmp…" button.
@main
struct MiniDumpTruckGUIApp: App {
    let initialPath: String?

    init() {
        initialPath = CommandLine.arguments.dropFirst().first
    }

    var body: some Scene {
        WindowGroup("MiniDumpTruck") {
            RootView(initialPath: initialPath)
        }
        .defaultSize(width: 980, height: 680)
    }
}
