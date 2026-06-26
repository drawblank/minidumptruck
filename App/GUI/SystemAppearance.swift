import Foundation
import SwiftCrossUI

/// Detects the desktop's light/dark preference at launch.
///
/// swift-cross-ui's GTK backend doesn't bridge the system color scheme into its
/// environment (`canOverrideWindowColorScheme == false`), so its `colorScheme`
/// stays `.light` and unset text resolves to black — even on a dark GTK theme.
/// We read the preference ourselves and feed it to `.colorScheme(_:)` so the
/// default text colour tracks the theme instead of being hard-light.
///
/// Signals, in priority order (all Linux/GTK conventions):
///   1. `GTK_THEME` env var with a `dark` variant (explicit override).
///   2. `gtk-application-prefer-dark-theme` in the GTK settings.ini.
/// Detection is at startup only; it doesn't react to a live theme switch yet.
func systemColorScheme() -> ColorScheme {
    let env = ProcessInfo.processInfo.environment

    if let gtkTheme = env["GTK_THEME"]?.lowercased(), gtkTheme.contains("dark") {
        return .dark
    }

    let configHome = env["XDG_CONFIG_HOME"].map(URL.init(fileURLWithPath:))
        ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
    let iniPaths = [
        configHome.appendingPathComponent("gtk-4.0/settings.ini"),
        configHome.appendingPathComponent("gtk-3.0/settings.ini"),
    ]
    for path in iniPaths {
        guard let ini = try? String(contentsOf: path, encoding: .utf8) else { continue }
        if ini.range(of: #"gtk-application-prefer-dark-theme\s*=\s*(true|1)"#,
                     options: [.regularExpression, .caseInsensitive]) != nil {
            return .dark
        }
        if ini.range(of: #"gtk-application-prefer-dark-theme\s*=\s*(false|0)"#,
                     options: [.regularExpression, .caseInsensitive]) != nil {
            return .light
        }
    }

    return .light
}
