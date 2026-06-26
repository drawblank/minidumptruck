# Project Index: MiniDumpTruck

Generated: 2026-06-26 · branch `cross-platform-support`

Analyzer for Windows crash dumps (`.dmp`) — WinDbg-like `!analyze` without
Windows. The non-UI core + CLI are cross-platform (macOS + Linux, Windows-aware);
a macOS SwiftUI app sits on top. Swift 5.9+ (Linux tested on 6.3).

## 📁 Project Structure

```
App/                         Swift package root (build/test here)
├── Package.swift            macOS app excluded from build on non-Apple hosts
├── CZlib/                   systemLibrary shim → links system zlib (off-Apple)
├── MiniDumpTruck/           MiniDumpTruckCore library + macOS app sources
│   ├── Models/      (21)    Minidump/PDB/PE/CONTEXT data structures
│   ├── Parsers/     (3)     MinidumpParser, MSFParser, PDBPublics
│   ├── Services/    (17)    CrashAnalyzer, symbolication, exporters, input
│   ├── Utilities/   (11)    BinaryReader, zip, NTStatus, Logger shim
│   ├── ViewModels/  (1)     DumpViewModel (macOS app)
│   └── Views/       (20)    SwiftUI app UI (macOS only)
├── CLI/             (7)     minidumptruck-cli (swift-argument-parser)
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

## 🚀 Entry Points

- **macOS app**: `App/MiniDumpTruck/MiniDumpTruckApp.swift` (`@main`, SwiftUI)
- **CLI**: `App/CLI/MinidumptruckCLI.swift` — subcommands `analyze` (default), `export`, `info`
- **Parser**: `App/MiniDumpTruck/Parsers/MinidumpParser.swift` — `parse(data:) -> ParsedMinidump`
- **Tests**: `App/Tests/` — `swift test`

## 📦 Core Modules (`MiniDumpTruckCore`)

- **Parsers**: `MinidumpParser` (stream directory → `ParsedMinidump`), `MSFParser` (PDB container), `PDBPublics`.
- **Services**: `CrashAnalyzer` (`analyze()` → stack walk + blame), `UnwindStackWalker` (x64/ARM64), `Symbolicator`/`SymbolicationService` (PDB fetch+resolve), `SymbolCache`/`SymbolServer`/`SymbolServerTrust`, exporters (`JSON`/`CSV`/`HTML`/`Text`/`Batch`), `InputPipeline`.
- **Models** (21): `MinidumpHeader`, `ThreadInfo`, `ModuleInfo`, `ExceptionInfo`, `SystemInfo`, `MiscInfo`, `MemoryRegion`, `HandleData`, `ThreadContext` (x64), `ARM64Context`, `PEImage`, `PDBSymbolTable`, `CrashAnalysis`, …
- **Utilities** (11): `BinaryReader` (LE), `DumpMemoryReader`, `ZipReader`, `InputSniffer`, `NTStatusCodes`, `Logger+Symbols` (os.Logger on Apple; stderr shim off-Apple), …

## 🔧 Build

```bash
cd App && swift build                 # core + CLI (+ macOS app on macOS)
cd App && swift build -c release
cd App && swift test                  # 839 on Linux / 846 on macOS
cd App && swift run minidumptruck-cli analyze TestData/full-dump.dmp
```

## 🔗 Dependencies

- `apple/swift-argument-parser` `1.7.0` (exact) — CLI parsing.
- `apple/swift-crypto` `3.0.0..<5.0.0` — SHA-256 (CryptoKit on Apple, BoringSSL off).
- System: SwiftUI/AppKit (macOS app); system `zlib` via `CZlib` (off-Apple ZIP DEFLATE).

## 🌍 Cross-platform decisions

- Logging: `import os` guarded by `canImport(os)`; stderr `Logger` shim off-Apple.
- SHA-256: swift-crypto (replaced CommonCrypto).
- ZIP DEFLATE: `Compression.framework` on Apple; system zlib via `CZlib` off-Apple.
- `URLSession`: `import FoundationNetworking` off-Apple.
- TLS pinning: `SecTrust`, Apple-only; `.systemTrust` (default) works everywhere.
- `TempStore.cleanupAged`: keys off modification date (Linux btime unreliable).

## 🧪 Tests

57 test files; 839 pass on Linux (846 on macOS — Apple-only TLS-pinning suite is
gated off-Apple). 8 fixture `.dmp` files + synthetic builders (`SyntheticDump`/
`PDB`/`PE`), `StubURLProtocol` for symbol-server tests.

## 📚 Docs

`README.md` (capability surface + CLI + cross-platform build), `CLI.md`,
`CLAUDE.md`, `CONTRIBUTING.md`, `docs/superpowers/{plans,specs}`. License: GPLv3.

## 📝 Quick Start

1. `cd App && swift build`
2. `swift run minidumptruck-cli analyze TestData/full-dump.dmp`
3. `swift test`
