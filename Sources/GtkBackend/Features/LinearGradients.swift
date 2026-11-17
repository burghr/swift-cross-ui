import CGtk
import Gtk
@_spi(Backends) import SwiftCrossUI

extension GtkBackend: BackendFeatures.LinearGradients {
    public func createLinearGradientWidget() -> Widget {
        GradientDrawingArea()
    }

    public func updateLinearGradientWidget(
        _ widget: Widget,
        gradient: LinearGradient,
        withSize size: SIMD2<Int>,
        in environment: EnvironmentValues
    ) {
        let drawingArea = widget as! GradientDrawingArea

        let startPoint = UnitPoint(
            x: Double(size.x) * gradient.startPoint.x,
            y: Double(size.y) * gradient.startPoint.y
        )

        let endPoint = UnitPoint(
            x: Double(size.x) * gradient.endPoint.x,
            y: Double(size.y) * gradient.endPoint.y
        )

        let stops = gradient.gradient.stops

        let colors = stops.map {
            $0.color.resolve(in: environment)
        }

        // A new draw function makes GTK draw the gradient again on the CPU.
        // Set it only when the gradient or its size changes. The size is in
        // the key because the draw function fills a rectangle of that size.
        var key: [Double] = [
            Double(size.x), Double(size.y),
            startPoint.x, startPoint.y, endPoint.x, endPoint.y,
        ]
        for (stop, color) in zip(stops, colors) {
            key += [
                stop.location, Double(color.red), Double(color.green),
                Double(color.blue), Double(color.opacity),
            ]
        }
        if drawingArea.drawKey == key {
            return
        }
        drawingArea.drawKey = key

        drawingArea.setDrawFunc { cairo, _, _ in
            let pattern = cairo_pattern_create_linear(
                startPoint.x,
                startPoint.y,
                endPoint.x,
                endPoint.y
            )

            for (index, stop) in stops.enumerated() {
                let color = colors[index]
                cairo_pattern_add_color_stop_rgba(
                    pattern,
                    stop.location,
                    Double(color.red),
                    Double(color.green),
                    Double(color.blue),
                    Double(color.opacity)
                )
            }

            cairo_set_source(cairo, pattern)
            cairo_rectangle(cairo, 0, 0, Double(size.x), Double(size.y))
            cairo_fill(cairo)
            cairo_pattern_destroy(pattern)
        }
    }
}
