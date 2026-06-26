import Foundation
import MiniDumpTruckCore
import SwiftCrossUI

/// Classic offset / hex / ASCII dump of a memory region. A simplified port of
/// the macOS `HexView` (no search/jump yet).
///
/// Rendered as a single monospaced `Text`, which GTK lays out as one big label,
/// so it must stay modest: bytes are capped, and the dump is formatted ONCE per
/// region (cached in `@State`) rather than on every layout/scroll pass — the
/// earlier per-byte `String(format:)` over 64 KB on every pass froze the UI.
struct HexDumpPane: View {
    let dump: ParsedMinidump
    let region: MemoryRegion

    /// Cap rendered bytes. One GtkLabel of N lines costs O(N) to measure, and
    /// `.fixedSize()` forces a full measure, so keep N small. 8 KB = 512 rows.
    private let maxBytes = 8 * 1024

    @State private var rendered: String = ""
    @State private var renderedRegionId: UUID?
    @State private var available = true

    var body: some View {
        // Hex lines are ~84 monospaced chars wide; a vertical-only ScrollView
        // would pass that width up to the enclosing HStack. Scroll BOTH axes and
        // let the hex Text take its natural (fixed) size — viewport stays bounded.
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(hexAddr(region.baseAddress)) – \(hexAddr(region.endAddress))  ·  \(ByteCountFormatter.string(fromByteCount: Int64(region.regionSize), countStyle: .memory))")
                    .foregroundColor(.gray)

                if available {
                    Text(rendered)
                        .fontDesign(.monospaced)
                        .fixedSize()
                    if Int(region.regionSize) > maxBytes {
                        Text("… showing first \(maxBytes / 1024) KB of \(ByteCountFormatter.string(fromByteCount: Int64(region.regionSize), countStyle: .memory))")
                            .foregroundColor(.gray)
                    }
                } else {
                    Text("Memory contents not available for this region.")
                        .foregroundColor(.gray)
                }
            }
            .padding(12)
        }
        .onAppear { loadIfNeeded() }
        .onChange(of: region.id) { loadIfNeeded() }
    }

    /// Read + format once per region, caching the result.
    private func loadIfNeeded() {
        guard renderedRegionId != region.id else { return }
        renderedRegionId = region.id

        let size = min(Int(region.regionSize), maxBytes)
        if size > 0, let data = MinidumpParser.readMemory(from: dump, at: region.baseAddress, size: size) {
            rendered = HexDump.format(data, baseAddress: region.baseAddress)
            available = true
        } else {
            rendered = ""
            available = false
        }
    }
}

/// Pure hex-dump formatter, split out so it's trivially testable.
///
/// Builds the whole dump into one byte buffer using a nibble lookup table — no
/// per-byte `String(format:)` (which is ~100× slower and was the load stall).
enum HexDump {
    private static let nibbles = Array("0123456789ABCDEF".utf8)
    private static let bytesPerRow = 16
    /// Width of the hex column for a full row: 16 bytes × "XX " (3) + 1 mid gap.
    private static let hexColumnWidth = bytesPerRow * 3 + 1

    static func format(_ data: Data, baseAddress: UInt64) -> String {
        let bytes = [UInt8](data)
        var out: [UInt8] = []
        out.reserveCapacity((bytes.count / bytesPerRow + 1) * 80)

        var offset = 0
        while offset < bytes.count {
            let end = min(offset + bytesPerRow, bytes.count)

            // Address column: 16 hex digits.
            let addr = baseAddress &+ UInt64(offset)
            var shift = 60
            while shift >= 0 {
                out.append(nibbles[Int((addr >> UInt64(shift)) & 0xF)])
                shift -= 4
            }
            out.append(0x20); out.append(0x20)

            // Hex column, padded to a fixed width so ASCII lines up.
            let hexStart = out.count
            var col = 0
            for i in offset..<end {
                let b = bytes[i]
                out.append(nibbles[Int(b >> 4)])
                out.append(nibbles[Int(b & 0xF)])
                out.append(0x20)
                col += 1
                if col == 8 { out.append(0x20) }  // gap between the two halves
            }
            var hexLen = out.count - hexStart
            while hexLen < hexColumnWidth { out.append(0x20); hexLen += 1 }
            out.append(0x20)

            // ASCII column.
            for i in offset..<end {
                let b = bytes[i]
                out.append((b >= 0x20 && b <= 0x7E) ? b : 0x2E)
            }

            out.append(0x0A)
            offset = end
        }

        return String(decoding: out, as: UTF8.self)
    }
}

private func hexAddr(_ v: UInt64) -> String { String(format: "0x%016llX", v) }
