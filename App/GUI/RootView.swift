import Foundation
import MiniDumpTruckCore
import SwiftCrossUI

/// A successfully parsed dump plus the name we show for it.
struct LoadedDump {
    let dump: ParsedMinidump
    let fileName: String
}

/// Outcome of attempting to open a file. (A plain `Result` won't do — its
/// `Failure` must be an `Error`, and we only need a display string.)
enum LoadOutcome {
    case ok(LoadedDump)
    case failed(String)
}

/// The app shell: a sidebar of sections + a detail pane, with an Open button.
/// Models the macOS `ContentView`/`SidebarView` (NavigationSplitView) on
/// swift-cross-ui.
struct RootView: View {
    @State var loaded: LoadedDump?
    @State var errorText: String?
    @State var selected: GUISection?

    @Environment(\.chooseFile) var chooseFile

    init(initialPath: String?) {
        if let initialPath {
            switch RootView.load(URL(fileURLWithPath: initialPath)) {
            case .ok(let d):
                _loaded = State(wrappedValue: d)
                _errorText = State(wrappedValue: nil)
            case .failed(let e):
                _loaded = State(wrappedValue: nil)
                _errorText = State(wrappedValue: e)
            }
        } else {
            _loaded = State(wrappedValue: nil)
            _errorText = State(wrappedValue: nil)
        }
        _selected = State(wrappedValue: .summary)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 220)
        } detail: {
            detail
        }
    }

    // MARK: Sidebar

    @ViewBuilder var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button("Open .dmp…") {
                Task { await openFile() }
            }
            .padding(8)

            if let loaded {
                List(loaded.dump.visibleSections, selection: $selected) { section in
                    HStack(spacing: 8) {
                        Text(section.rawValue)
                        Spacer()
                        if let badge = loaded.dump.badge(section) {
                            Text("\(badge)")
                                .foregroundColor(.gray)
                        }
                    }
                }
            } else {
                Spacer()
                Text("Open a .dmp file to begin")
                    .foregroundColor(.gray)
                    .padding(16)
                Spacer()
            }
        }
    }

    // MARK: Detail

    @ViewBuilder var detail: some View {
        if let errorText {
            VStack(alignment: .leading, spacing: 8) {
                Text("Parse Error")
                    .font(.system(size: 22))
                    .fontWeight(.bold)
                Text(errorText)
                    .foregroundColor(.red)
                Text("The file may be corrupted or not a valid Windows minidump.")
                    .foregroundColor(.gray)
            }
            .padding(16)
        } else if let loaded {
            sectionView(selected ?? .summary, loaded)
        } else {
            VStack {
                Text("No dump loaded")
                    .foregroundColor(.gray)
            }
            .padding(16)
        }
    }

    @ViewBuilder
    func sectionView(_ section: GUISection, _ loaded: LoadedDump) -> some View {
        let dump = loaded.dump
        switch section {
        case .summary:
            SummarySection(dump: dump, fileName: loaded.fileName)
        case .systemInfo:
            if let s = dump.systemInfo { SystemInfoSection(sys: s) } else { unavailable }
        case .miscInfo:
            if let m = dump.miscInfo { MiscInfoSection(misc: m) } else { unavailable }
        case .exception:
            if let e = dump.exception { ExceptionSection(exc: e) } else { unavailable }
        case .analyze:
            AnalyzeSection(dump: dump)
        case .threads:
            ThreadsSection(dump: dump)
        case .modules:
            ModulesSection(dump: dump)
        case .handles:
            HandlesSection(dump: dump)
        case .memory:
            MemorySection(dump: dump)
        case .streams:
            StreamsSection(dump: dump)
        }
    }

    @ViewBuilder var unavailable: some View {
        VStack {
            Text("Not available in this dump")
                .foregroundColor(.gray)
        }
        .padding(16)
    }

    // MARK: Loading

    func openFile() async {
        guard let url = await chooseFile(allowSelectingFiles: true) else { return }
        switch RootView.load(url) {
        case .ok(let d):
            loaded = d
            errorText = nil
            selected = .summary
        case .failed(let e):
            errorText = e
            loaded = nil
        }
    }

    static func load(_ url: URL) -> LoadOutcome {
        do {
            let data = try Data(contentsOf: url)
            let dump = try MinidumpParser.parse(data: data)
            return .ok(LoadedDump(dump: dump, fileName: url.lastPathComponent))
        } catch {
            return .failed("Failed to open \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }
}

extension ParsedMinidump {
    /// Sections with data, in sidebar order.
    var visibleSections: [GUISection] {
        GUISection.allCases.filter { isVisible($0) }
    }
}
