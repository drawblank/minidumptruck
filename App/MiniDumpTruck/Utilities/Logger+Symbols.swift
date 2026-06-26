#if canImport(os)
import os

/// Centralized `os_log` subsystem for the symbol-resolution pipeline.
///
/// Subsystem: `com.minidumptruck` (matches the bundle identifier).
/// Categories: `symbols` for cache / server / parser events.
///
/// Visible to users via Console.app filtered on `subsystem ==
/// "com.minidumptruck"`. Power users debugging "why aren't symbols
/// resolving" can answer the question without reaching for a debugger.
extension Logger {
    public static let symbols = Logger(
        subsystem: "com.minidumptruck",
        category: "symbols"
    )
}
#else
import Foundation

/// Minimal cross-platform stand-in for Apple's `os.Logger`, covering just
/// the surface the symbol pipeline uses. Apple builds get the real
/// unified-logging `Logger`; on Linux (and future Windows) this writes a
/// formatted line to stderr.
///
/// `privacy:` annotations are accepted for source compatibility and then
/// ignored — there is no unified-logging redaction store off-Apple to
/// honor them. Call sites are identical across platforms, e.g.
/// `Logger.symbols.error("fetch failed for \(name, privacy: .public)")`.
public struct Logger: Sendable {
    private let subsystem: String
    private let category: String

    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    public static let symbols = Logger(
        subsystem: "com.minidumptruck",
        category: "symbols"
    )

    public func trace(_ message: LogMessage)  { emit("TRACE", message) }
    public func debug(_ message: LogMessage)  { emit("DEBUG", message) }
    public func info(_ message: LogMessage)   { emit("INFO", message) }
    public func notice(_ message: LogMessage) { emit("NOTICE", message) }
    public func warning(_ message: LogMessage) { emit("WARNING", message) }
    public func error(_ message: LogMessage)  { emit("ERROR", message) }
    public func fault(_ message: LogMessage)  { emit("FAULT", message) }
    public func log(_ message: LogMessage)    { emit("LOG", message) }

    private func emit(_ level: String, _ message: LogMessage) {
        let line = "[\(subsystem):\(category)] \(level): \(message.rendered)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}

/// Privacy annotation accepted for source-compatibility with `os.Logger`
/// string interpolation. Ignored off-Apple.
public enum LogPrivacy: Sendable {
    case `public`
    case `private`
    case auto
}

/// Interpolatable log message mirroring the subset of `OSLogMessage`'s
/// interpolation the codebase uses: plain values and `value, privacy:`.
public struct LogMessage: ExpressibleByStringInterpolation, Sendable {
    let rendered: String

    public init(stringLiteral value: String) {
        self.rendered = value
    }

    public init(stringInterpolation: Interpolation) {
        self.rendered = stringInterpolation.text
    }

    public struct Interpolation: StringInterpolationProtocol, Sendable {
        var text = ""

        public init(literalCapacity: Int, interpolationCount: Int) {
            text.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            text += literal
        }

        public mutating func appendInterpolation(_ value: String, privacy: LogPrivacy = .auto) {
            text += value
        }

        public mutating func appendInterpolation(
            _ value: some CustomStringConvertible,
            privacy: LogPrivacy = .auto
        ) {
            text += value.description
        }
    }
}
#endif
