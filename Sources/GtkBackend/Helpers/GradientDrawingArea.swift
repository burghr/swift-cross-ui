import Gtk

/// A drawing area that keeps the parameters of its current draw function.
///
/// A new draw function makes GTK draw the gradient again on the CPU. The
/// backend compares the parameters and sets a new draw function only when
/// they change.
final class GradientDrawingArea: DrawingArea {
    var drawKey: [Double]?
}
