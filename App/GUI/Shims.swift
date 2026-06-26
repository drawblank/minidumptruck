import SwiftCrossUI

/// Small reusable components filling the gaps between SwiftUI (which the macOS
/// app uses) and swift-cross-ui. Keeping them in one place means the ported
/// views read almost identically to their SwiftUI originals.

/// A titled container, standing in for SwiftUI's `GroupBox` (the single
/// most-used primitive in the macOS views). Renders a bold grey caption above
/// an indented content block.
struct GroupBox<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
        }
        .padding(10)
    }
}

/// A label/value row, standing in for the `LabeledContent`/`Form` rows the
/// macOS views use. The label is fixed-width-ish (grey), the value trails.
struct LabeledRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
        }
    }
}

/// A scrollable, padded page wrapper used by every detail section so they
/// share consistent margins and scrolling behaviour.
struct DetailPage<Content: View>: View {
    let heading: String
    @ViewBuilder var content: () -> Content

    init(_ heading: String, @ViewBuilder content: @escaping () -> Content) {
        self.heading = heading
        self.content = content
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(heading)
                    .font(.system(size: 22))
                    .fontWeight(.bold)
                content()
            }
            .padding(16)
        }
    }
}
