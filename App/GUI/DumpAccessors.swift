import Foundation
import MiniDumpTruckCore

/// Sidebar sections, mirroring the macOS app's `NavigationSection` (minus the
/// SF Symbol names, which don't apply off-Apple).
enum GUISection: String, CaseIterable, Identifiable {
    case summary = "Summary"
    case systemInfo = "System Info"
    case miscInfo = "Misc Info"
    case exception = "Exception"
    case analyze = "Analyze"
    case threads = "Threads"
    case modules = "Modules"
    case handles = "Handles"
    case memory = "Memory"
    case streams = "Streams"

    // ID is the case itself (like swift-cross-ui's SplitExample) so a
    // List's `selection` binds directly to `GUISection?`.
    var id: Self { self }
}

/// Convenience accessors over a parsed dump, matching the names the macOS
/// `MinidumpDocument` exposes so the ported views read the same.
extension ParsedMinidump {
    var threads: [ThreadInfo] { threadList?.threads ?? [] }
    var modules: [ModuleInfo] { moduleList?.modules ?? [] }
    var handles: [HandleEntry] { handleData?.entries ?? [] }
    var memoryRegions: [MemoryRegion] {
        let regions64 = memory64List?.regions ?? []
        if !regions64.isEmpty { return regions64 }
        return memoryList?.regions ?? []
    }
    var memoryInfoEntries: [MemoryInfo] { memoryInfoList?.entries ?? [] }
    var unloadedModules: [UnloadedModule] { unloadedModuleList?.modules ?? [] }

    /// Which sidebar sections have data worth showing for this dump.
    func isVisible(_ section: GUISection) -> Bool {
        switch section {
        case .summary: return true
        case .systemInfo: return systemInfo != nil
        case .miscInfo: return miscInfo != nil
        case .exception: return exception != nil
        case .analyze: return exception != nil
        case .threads: return !threads.isEmpty
        case .modules: return !modules.isEmpty
        case .handles: return !handles.isEmpty
        case .memory: return !memoryRegions.isEmpty || !memoryInfoEntries.isEmpty
        case .streams: return !streamDirectory.entries.isEmpty
        }
    }

    /// Count badge for a section, or nil when a badge doesn't apply.
    func badge(_ section: GUISection) -> Int? {
        switch section {
        case .threads: return threads.count
        case .modules: return modules.count
        case .handles: return handles.count
        case .memory: return memoryRegions.count
        case .streams: return streamDirectory.entries.count
        default: return nil
        }
    }
}
