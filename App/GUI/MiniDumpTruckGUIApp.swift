import DefaultBackend
import Foundation
import MiniDumpTruckCore
import SwiftCrossUI

/// Vertical-slice cross-platform GUI.
///
/// Loads a `.dmp` passed on the command line and renders the same text report
/// the CLI produces — proving the swift-cross-ui toolchain end to end on Linux
/// (GTK4). This is the skeleton the full view port grows on top of; the
/// macOS SwiftUI views get ported to swift-cross-ui incrementally from here,
/// and the AppKit backend is folded in at the unification step.
@main
struct MiniDumpTruckGUIApp: App {
    let windowTitle: String
    let report: String

    init() {
        guard let path = CommandLine.arguments.dropFirst().first else {
            windowTitle = "MiniDumpTruck"
            report = """
                Open a crash dump by passing a .dmp path:

                    MiniDumpTruckGUI <file.dmp>
                """
            return
        }

        let url = URL(fileURLWithPath: path)
        windowTitle = "MiniDumpTruck — \(url.lastPathComponent)"
        do {
            let data = try Data(contentsOf: url)
            let dump = try MinidumpParser.parse(data: data)
            report = TextReporter.generateReport(
                from: dump,
                analysis: nil,
                fileName: url.lastPathComponent
            )
        } catch {
            report = "Failed to open \(url.lastPathComponent):\n\n\(error.localizedDescription)"
        }
    }

    var body: some Scene {
        WindowGroup(windowTitle) {
            ScrollView {
                Text(report)
                    .fontDesign(.monospaced)
                    .padding()
            }
        }
        .defaultSize(width: 820, height: 620)
    }
}
