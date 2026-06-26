import Foundation
import MiniDumpTruckCore
import SwiftCrossUI

/// Classic offset / hex / ASCII dump of a memory region. A simplified port of
/// the macOS `HexView` (no search/jump yet) — reads bytes from the dump and
/// renders a monospaced block, capped so very large regions stay responsive.
struct HexDumpPane: View {
    let dump: ParsedMinidump
    let region: MemoryRegion

    /// Cap rendered bytes — a multi-MB region as one Text would be sluggish.
    private let maxBytes = 64 * 1024

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(hexAddr(region.baseAddress)) – \(hexAddr(region.endAddress))  ·  \(ByteCountFormatter.string(fromByteCount: Int64(region.regionSize), countStyle: .memory))")
                    .foregroundColor(.gray)

                if let data = readBytes() {
                    Text(HexDump.format(data, baseAddress: region.baseAddress))
                        .fontDesign(.monospaced)
                    if Int(region.regionSize) > maxBytes {
                        Text("… truncated to first \(maxBytes / 1024) KB of \(ByteCountFormatter.string(fromByteCount: Int64(region.regionSize), countStyle: .memory))")
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("Memory contents not available for this region.")
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
        }
    }

    private func readBytes() -> Data? {
        let size = min(Int(region.regionSize), maxBytes)
        guard size > 0 else { return nil }
        return MinidumpParser.readMemory(from: dump, at: region.baseAddress, size: size)
    }
}

/// Pure hex-dump formatter, split out so it's trivially testable.
enum HexDump {
    static func format(_ data: Data, baseAddress: UInt64) -> String {
        let bytes = [UInt8](data)
        var lines: [String] = []
        var offset = 0
        while offset < bytes.count {
            let end = min(offset + 16, bytes.count)
            let chunk = Array(bytes[offset..<end])

            let addrCol = String(format: "%016llX", baseAddress &+ UInt64(offset))
            var hexCol = ""
            for (i, b) in chunk.enumerated() {
                hexCol += String(format: "%02X ", b)
                if i == 7 { hexCol += " " }  // gap between the two 8-byte halves
            }
            // Pad to a fixed width so the ASCII column lines up: 16*3 + 1 = 49.
            hexCol = hexCol.padding(toLength: 49, withPad: " ", startingAt: 0)
            let ascii = String(chunk.map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : "." })

            lines.append("\(addrCol)  \(hexCol) \(ascii)")
            offset = end
        }
        return lines.joined(separator: "\n")
    }
}

private func hexAddr(_ v: UInt64) -> String { String(format: "0x%016llX", v) }
