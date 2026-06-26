import Foundation
import MiniDumpTruckCore
import SwiftCrossUI

// Hex formatting helpers, kept local so the views read cleanly.
private func hex(_ v: UInt64) -> String { String(format: "0x%llX", v) }
private func addr(_ v: UInt64) -> String { String(format: "0x%016llX", v) }
private func hex32(_ v: UInt32) -> String { String(format: "0x%08X", v) }

/// Heading + a scrolling column of rows. swift-cross-ui's `List` is
/// selection-only, so non-selectable record lists use `ScrollView { ForEach }`
/// (the ColorsExample / ForEachExample idiom) instead.
private struct ListPage<Content: View>: View {
    let heading: String
    @ViewBuilder var content: () -> Content
    init(_ heading: String, @ViewBuilder content: @escaping () -> Content) {
        self.heading = heading
        self.content = content
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(heading)
                    .font(.system(size: 22))
                    .fontWeight(.bold)
                content()
            }
            .padding(16)
        }
    }
}

// MARK: - Summary

struct SummarySection: View {
    let dump: ParsedMinidump
    let fileName: String

    var body: some View {
        DetailPage("Summary") {
            GroupBox("File") {
                LabeledRow("Name", fileName)
                LabeledRow("Timestamp", dump.header.timestamp.formatted())
                LabeledRow("Size", ByteCountFormatter.string(
                    fromByteCount: Int64(dump.data.count), countStyle: .file))
                LabeledRow("Streams", "\(dump.streamDirectory.entries.count)")
                LabeledRow("Flags", dump.header.flagsDescription.joined(separator: ", "))
            }
            if let exc = dump.exception {
                GroupBox("Exception") {
                    LabeledRow("Code", "\(hex32(exc.exceptionCode))  \(exc.exceptionName)")
                    LabeledRow("Address", addr(exc.exceptionAddress))
                    LabeledRow("Thread", "\(exc.threadId)")
                }
            }
            GroupBox("Contents") {
                LabeledRow("Threads", "\(dump.threads.count)")
                LabeledRow("Modules", "\(dump.modules.count)")
                LabeledRow("Memory regions", "\(dump.memoryRegions.count)")
                LabeledRow("Handles", "\(dump.handles.count)")
            }
            if !dump.parseWarnings.isEmpty {
                GroupBox("Parse warnings (\(dump.parseWarnings.count))") {
                    ForEach(dump.parseWarnings, id: \.id) { w in
                        Text("• \(w.message.sanitizedForOutput())")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - System Info

struct SystemInfoSection: View {
    let sys: SystemInfo

    var body: some View {
        DetailPage("System Info") {
            GroupBox("Operating System") {
                LabeledRow("OS", sys.osVersionString.sanitizedForOutput())
                LabeledRow("Build", "\(sys.buildNumber)")
                LabeledRow("Architecture", sys.processorArchitecture.displayName)
                LabeledRow("Processors", "\(sys.numberOfProcessors)")
            }
            GroupBox("CPU") {
                LabeledRow("Vendor", sys.cpuInfo.vendorString)
                LabeledRow("Family", "\(sys.cpuInfo.displayFamily)")
                LabeledRow("Model", "\(sys.cpuInfo.displayModel)")
                LabeledRow("Stepping", "\(sys.cpuInfo.stepping)")
            }
        }
    }
}

// MARK: - Misc Info

struct MiscInfoSection: View {
    let misc: MiscInfo

    var body: some View {
        DetailPage("Misc Info") {
            GroupBox("Process") {
                if let pid = misc.processId { LabeledRow("Process ID", "\(pid)") }
                if let t = misc.processCreateTime { LabeledRow("Created", t.formatted()) }
                if let u = misc.processUserTime { LabeledRow("User time", String(format: "%.2fs", u)) }
                if let k = misc.processKernelTime { LabeledRow("Kernel time", String(format: "%.2fs", k)) }
            }
            GroupBox("Processor") {
                if let m = misc.processorCurrentMhz { LabeledRow("Current MHz", "\(m)") }
                if let m = misc.processorMaxMhz { LabeledRow("Max MHz", "\(m)") }
            }
        }
    }
}

// MARK: - Exception

struct ExceptionSection: View {
    let exc: ExceptionInfo

    var body: some View {
        DetailPage("Exception") {
            GroupBox("Details") {
                LabeledRow("Code", hex32(exc.exceptionCode))
                LabeledRow("Name", exc.exceptionName)
                LabeledRow("Address", addr(exc.exceptionAddress))
                LabeledRow("Thread ID", "\(exc.threadId)")
                if exc.exceptionFlags != 0 {
                    LabeledRow("Flags", hex32(exc.exceptionFlags))
                }
            }
            Text(exc.exceptionDescription)
                .foregroundColor(.gray)
                .padding(10)
            if !exc.exceptionParameters.isEmpty {
                GroupBox("Parameters") {
                    ForEach(Array(exc.exceptionParameters.enumerated()), id: \.offset) { item in
                        LabeledRow("[\(item.offset)]", addr(item.element))
                    }
                }
            }
        }
    }
}

// MARK: - Analyze

struct AnalyzeSection: View {
    let dump: ParsedMinidump

    var body: some View {
        DetailPage("Analyze") {
            if let analysis = CrashAnalyzer(dump: dump).analyze() {
                GroupBox("Verdict") {
                    LabeledRow("Exception", analysis.crashSummary.exceptionType)
                    if let blame = analysis.blameModule {
                        LabeledRow("Blamed module", blame.module.shortName)
                        Text(blame.reasonDescription)
                            .foregroundColor(.gray)
                    }
                    LabeledRow("Confidence", "\(analysis.confidence)")
                }
                GroupBox("Call stack (\(analysis.stackFrames.count) frames)") {
                    ForEach(analysis.stackFrames, id: \.id) { frame in
                        Text(frameLine(frame))
                            .fontDesign(.monospaced)
                    }
                }
            } else {
                Text("No crash analysis available for this dump.")
                    .foregroundColor(.gray)
                    .padding(10)
            }
        }
    }

    private func frameLine(_ frame: StackFrame) -> String {
        let module = frame.module?.shortName ?? "?"
        let symbol = frame.symbol?.function
        if let symbol {
            return "\(frame.displayAddress)  \(module)!\(symbol)"
        }
        if let off = frame.offsetInModule {
            return "\(frame.displayAddress)  \(module)+\(hex(off))"
        }
        return "\(frame.displayAddress)  \(module)"
    }
}

// MARK: - Threads

struct ThreadsSection: View {
    let dump: ParsedMinidump
    private var faultingId: UInt32? { MinidumpParser.faultingThread(in: dump)?.id }

    var body: some View {
        ListPage("Threads (\(dump.threads.count))") {
            ForEach(dump.threads, id: \.id) { thread in
                HStack(spacing: 12) {
                    Text("Thread \(thread.id)")
                        .fontDesign(.monospaced)
                    if thread.id == faultingId {
                        Text("⚠ faulting")
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Text("stack \(hex(thread.stack.startOfMemoryRange))")
                        .foregroundColor(.gray)
                        .fontDesign(.monospaced)
                }
            }
        }
    }
}

// MARK: - Modules

struct ModulesSection: View {
    let dump: ParsedMinidump

    var body: some View {
        ListPage("Modules (\(dump.modules.count))") {
            ForEach(dump.modules, id: \.id) { module in
                HStack(spacing: 12) {
                    Text(module.shortName)
                    Spacer()
                    Text("\(addr(module.baseAddress))  \(ByteCountFormatter.string(fromByteCount: Int64(module.sizeOfImage), countStyle: .memory))")
                        .foregroundColor(.gray)
                        .fontDesign(.monospaced)
                }
            }
        }
    }
}

// MARK: - Handles

struct HandlesSection: View {
    let dump: ParsedMinidump

    var body: some View {
        ListPage("Handles (\(dump.handles.count))") {
            ForEach(dump.handles, id: \.id) { handle in
                HStack(spacing: 12) {
                    Text(handle.typeName.isEmpty ? "(handle)" : handle.typeName)
                    Spacer()
                    Text(handle.objectName)
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Memory

struct MemorySection: View {
    let dump: ParsedMinidump

    var body: some View {
        ListPage("Memory regions (\(dump.memoryRegions.count))") {
            ForEach(dump.memoryRegions, id: \.id) { region in
                HStack(spacing: 12) {
                    Text(addr(region.baseAddress))
                        .fontDesign(.monospaced)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: Int64(region.regionSize), countStyle: .memory))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: - Streams

struct StreamsSection: View {
    let dump: ParsedMinidump

    var body: some View {
        ListPage("Streams (\(dump.streamDirectory.entries.count))") {
            ForEach(dump.streamDirectory.entries, id: \.id) { entry in
                HStack(spacing: 12) {
                    Text(entry.displayName)
                    Spacer()
                    Text("\(ByteCountFormatter.string(fromByteCount: Int64(entry.dataSize), countStyle: .file)) @ \(hex32(entry.rva))")
                        .foregroundColor(.gray)
                        .fontDesign(.monospaced)
                }
            }
        }
    }
}
