import CGtk
import Gtk
@_spi(Backends) import SwiftCrossUI

extension GtkBackend: BackendFeatures.TextViews {
    public func size(
        of text: String,
        whenDisplayedIn widget: Widget,
        proposedWidth: Int?,
        proposedHeight: Int?,
        environment: EnvironmentValues
    ) -> SIMD2<Int> {
        // Text editors are not cached, because their text can be long and
        // changes with each key press.
        guard widget is CustomLabel else {
            return measureTextSize(
                of: text,
                whenDisplayedIn: widget,
                proposedWidth: proposedWidth,
                proposedHeight: proposedHeight,
                environment: environment
            )
        }

        let key = TextSizeKey(
            text: text,
            font: environment.resolvedFont,
            proposedWidth: proposedWidth,
            proposedHeight: proposedHeight,
            lineLimit: environment.lineLimitSettings
        )
        if let size = textSizeCache[key] {
            return size
        }

        let size = measureTextSize(
            of: text,
            whenDisplayedIn: widget,
            proposedWidth: proposedWidth,
            proposedHeight: proposedHeight,
            environment: environment
        )
        // Keep the memory use small. A full clear is simple, and the cache
        // fills again with the text that is on the screen.
        if textSizeCache.count >= TextSizeKey.maximumCount {
            textSizeCache.removeAll(keepingCapacity: true)
        }
        textSizeCache[key] = size
        return size
    }

    private func measureTextSize(
        of text: String,
        whenDisplayedIn widget: Widget,
        proposedWidth: Int?,
        proposedHeight: Int?,
        environment: EnvironmentValues
    ) -> SIMD2<Int> {
        let ellipsize: EllipsizeMode
        if let widget = widget as? CustomLabel {
            ellipsize = widget.ellipsize
        } else if widget as? TextView != nil {
            // We don't ellipsize multi-line text editors
            ellipsize = .none
        } else {
            logger.warning(
                "\(#function) called with unexpected widget type \(type(of: widget))"
            )
            ellipsize = .none
        }

        let pango = Pango(for: widget)
        let (width, height) = pango.getTextSize(
            text,
            ellipsize: proposedHeight == nil ? .none : ellipsize,
            proposedWidth: proposedWidth.map(Double.init),
            proposedHeight: proposedHeight.map(Double.init)
        )

        var imposedHeight = height

        if let lineLimitSettings = environment.lineLimitSettings {
            let multilineString = [String](repeating: "a", count: lineLimitSettings.limit)
                .joined(separator: "\n")
            updateTextView(
                measurementCustomLabel,
                content: "",
                environment: environment
            )

            let pango = Pango(for: measurementCustomLabel)

            let (_, heightLimit) = pango.getTextSize(
                multilineString,
                ellipsize: .none,
                proposedWidth: nil,
                proposedHeight: nil
            )

            if heightLimit < imposedHeight || lineLimitSettings.reservesSpace {
                imposedHeight = heightLimit
            }
        }

        return SIMD2(width, imposedHeight)
    }

    public func createTextView() -> Widget {
        let textView = CustomLabel(string: "")
        textView.horizontalAlignment = .start
        textView.wrap = true
        textView.lineWrapMode = .wordCharacter
        textView.ellipsize = .end
        textView.yalign = 0.0
        return textView
    }

    public func updateTextView(
        _ textView: Widget,
        content: String,
        environment: EnvironmentValues
    ) {
        let textView = textView as! CustomLabel
        if textView.label != content {
            textView.label = content
        }
        textView.justify =
            switch environment.multilineTextAlignment {
                case .leading:
                    Justification.left
                case .center:
                    Justification.center
                case .trailing:
                    Justification.right
            }

        textView.selectable = environment.isTextSelectionEnabled
        textView.css.set(properties: Self.cssProperties(for: environment), clear: true)
    }
}

/// The values that the size of a text view depends on.
///
/// Each measurement makes a new Pango context, and GTK then computes the CSS
/// style again. That is slow, so ``GtkBackend`` keeps the measured sizes.
///
/// The CSS of a text view comes from the environment (see
/// ``GtkBackend/cssProperties(for:isControl:)``), and only the font changes
/// the size. Text views always use the `end` ellipsis mode.
struct TextSizeKey: Hashable {
    /// The maximum number of sizes in the cache.
    static let maximumCount = 20_000

    var text: String
    var font: Font.Resolved
    var proposedWidth: Int?
    var proposedHeight: Int?
    var lineLimit: LineLimit?
}
