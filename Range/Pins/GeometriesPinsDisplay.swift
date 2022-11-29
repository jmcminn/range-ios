import Foundation
import MapboxMaps

/// Interface for classes implementing Geometries pins display
protocol GeometriesPinsDisplay: AnyObject {
    /// - Parameters:
    ///   - canvas:                            will add pins for this canvas
    ///   - canvasViewController:              will add pins to this canvas view
    ///   - deselectOnCanvasTap:               should the display deselect the currently selected pin if user taps on the canvas outside of any pin
    ///   - geometryPinDisplayOptionsProvider: the function providing pin display options given geometry and selection state
    init(canvas: PDFCanvas,
         canvasViewController: PDFCanvasViewController,
         deselectOnCanvasTap: Bool,
         geometryPinDisplayOptionsProvider: @escaping GeometryPinDisplayOptionsProvider)

    /// Display the pins and listen for changes
    ///  - Parameters:
    ///         - onInitialLoad: callback called only once when the pins are initially loaded
    func start(onInitialLoad: (() -> Void)?)

    /// Hide the pins and stop listening for changes
    func stop()

    /// Returns pin for given geometry id or nil if no pin for this geometry is displayed
    func pinForGeometryId(_ geometryId: String) -> PinPoint?

    /// Returns the pin closest to the given point. The pin must be within the square centered at the point and with given size
    /// - Parameters:
    ///     - point: the center point
    ///     - searchSquareSize: the length of the square side
    ///     - completion: callback to be called with the result
    func findPin(closestToPoint point: CGPoint, searchSquareSize: CGFloat, completion: @escaping (PinPoint?) -> Void)

    /// Whether the pins display is currently started or not (not started yet or stopped)
    var started: Bool { get }

    /// Currently selected pin
    var selectedPin: PinPoint? { get }

    /// Mark given pin as selected
    func setSelectedPin(_ pinPoint: PinPoint?)

    /// A way for listener to register for user pin selection
    var onSelectedPinChange: ((PinPoint?) -> Void)? { get set }
}
