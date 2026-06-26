# Project Index: MiniDumpTruck

Generated: 2026-06-26 · branch `cross-platform-gui`

Analyzer for Windows crash dumps (`.dmp`) — WinDbg-like `!analyze` without
Windows. The non-UI core + CLI are cross-platform (macOS + Linux, Windows-aware);
a macOS SwiftUI app and an in-progress cross-platform (GTK4) GUI sit on top.
Swift 5.9+ (Linux tested on 6.3).

## 📁 Project Structure

```
App/                         Swift package root (build/test here)
├── Package.swift            Products vary by host (see below)
├── CZlib/                   systemLibrary shim → links system zlib (off-Apple)
├── MiniDumpTruck/           MiniDumpTruckCore library + macOS app sources
│   ├── Models/      (21)    Minidump/PDB/PE/CONTEXT data structures
│   ├── Parsers/     (3)     MinidumpParser, MSFParser, PDBPublics
│   ├── Services/    (17)    CrashAnalyzer, symbolication, exporters, input
│   ├── Utilities/   (11)    BinaryReader, zip, hex, NTStatus, Logger shim
│   ├── ViewModels/  (1)     DumpViewModel (macOS app)
│   └── Views/       (20)    SwiftUI app UI (macOS only)
├── CLI/             (7)     minidumptruck-cli (swift-argument-parser)
├── GUI/             (7)     MiniDumpTruckGUI — swift-cross-ui port (Linux/GTK4)
├── Tests/           (57)    XCTest/Testing suites against the core
└── TestData/        (8 .dmp) Fixture crash dumps + README
docs/superpowers/            Design plans & specs
scripts/build-app.sh         macOS .app/DMG build
.github/workflows/           ci.yml (build+test), release.yml
```

**Products (host-conditional in Package.swift):**
- `MiniDumpTruckCore` (library) — portable parser/analyzer/services. All hosts.
- `minidumptruck-cli` (executable) — CLI. All hosts.
- `MiniDumpTruck` (executable) — SwiftUI app. **macOS only.**
- `MiniDumpTruckGUI` (executable) — swift-cross-ui GUI. **non-macOS** (Linux/GTK4).

## 🚀 Entry Points

- **macOS app**: `App/MiniDumpTruck/MiniDumpTruckApp.swift` (`@main`, SwiftUI)
- **Cross-platform GUI**: `App/GUI/MiniDumpTruckGUIApp.swift` (`@main`, swift-cross-ui)
- **CLI**: `App/CLI/MinidumptruckCLI.swift` — subcommands `analyze` (default), `export`, `info`
- **Parser**: `App/MiniDumpTruck/Parsers/MinidumpParser.swift` — `parse(data:) -> ParsedMinidump`
- **Tests**: `App/Tests/` — `swift test`

## 📦 Core Modules (`MiniDumpTruckCore`)

- **Parsers**: `MinidumpParser` (stream directory → `ParsedMinidump`), `MSFParser` (PDB container), `PDBPublics`.
- **Services**: `CrashAnalyzer` (`analyze()` → stack walk + blame), `UnwindStackWalker` (x64/ARM64), `Symbolicator`/`SymbolicationService` (PDB fetch+resolve), `SymbolCache`/`SymbolServer`/`SymbolServerTrust`, exporters (`JSON`/`CSV`/`HTML`/`Text`/`Batch`), `InputPipeline`.
- **Models** (21): `MinidumpHeader`, `ThreadInfo`, `ModuleInfo`, `ExceptionInfo`, `SystemInfo`, `MiscInfo`, `MemoryRegion`, `HandleData`, `ThreadContext` (x64), `ARM64Context`, `PEImage`, `PDBSymbolTable`, `CrashAnalysis`, …
- **Utilities** (11): `BinaryReader` (LE), `DumpMemoryReader`, `ZipReader`, `InputSniffer`, `NTStatusCodes`, `Logger+Symbols` (os.Logger on Apple; stderr shim off-Apple), …

## 🖥️ GUI target (`App/GUI/`)

swift-cross-ui port driven by `MiniDumpTruckCore`. `RootView` (NavigationSplitView
+ file open + HTML/CSV export + PDB symbolication), `Sections` (10 detail
sections), `HexDump` (offset/hex/ASCII memory view), `Shims` (GroupBox/LabeledRow),
`SystemAppearance` (dark-mode detection), `DumpAccessors`.

## 🔧 Build

```bash
cd App && swift build                 # core + CLI (+ macOS app on macOS, GUI off-Apple)
cd App && swift build -c release
cd App && swift test                  # 839 on Linux / 846 on macOS
cd App && swift run minidumptruck-cli analyze TestData/full-dump.dmp
cd App && swift run MiniDumpTruckGUI TestData/full-dump.dmp   # Linux (needs GTK4)
```

## 🔗 Dependencies

- `apple/swift-argument-parser` `1.7.0` (exact) — CLI parsing.
- `apple/swift-crypto` `3.0.0..<5.0.0` — SHA-256 (CryptoKit on Apple, BoringSSL off).
- `stackotter/swift-cross-ui` `0.1.0+` — cross-platform GUI toolkit (GTK4/WinUI/AppKit).
- System: SwiftUI/AppKit (macOS app); GTK4 + system `zlib` via `CZlib` (Linux GUI).

## 🧪 Tests

57 test files; 839 pass on Linux (846 on macOS — Apple-only TLS-pinning suite is
gated off-Apple). 8 fixture `.dmp` files + synthetic builders (`SyntheticDump`/
`PDB`/`PE`), `StubURLProtocol` for symbol-server tests.

## 📚 Docs

`README.md` (capability surface + CLI + cross-platform build), `CLI.md`,
`CLAUDE.md`, `CONTRIBUTING.md`, `docs/superpowers/{plans,specs}`. License: GPLv3.

## 📝 Quick Start

1. `cd App && swift build`
2. `swift run minidumptruck-cli analyze TestData/full-dump.dmp` (CLI), or
   `swift run MiniDumpTruckGUI TestData/full-dump.dmp` (Linux GUI)
3. `swift test`
