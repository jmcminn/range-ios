import Foundation
import OSLog
import Turf
import UIKit

/// Delegate for `PinView` to notify about taps
protocol PinViewDelegate: AnyObject {
    func pinViewTapped(_ pinView: PinView)
}

/// PinView used for mapbox view annotations
/// This view needs to keep the Collaboration, because mapbox doesn't allow allow to access views by id, index, etc.
/// It only allows to use view itself as a way to identify the annotation, so we need to use it as a "view model"
class PinView: UIImageView {
    weak var delegate: PinViewDelegate?
    /// the id of the collaboration's geometry
    let id: String
    private(set) var point: Turf.Point
    private(set) var collaboration: Collaboration

    /// Initialize from given geometry. Once initialized the PinView should always be used for given geometry Id
    /// The geometry should have a collaboration that is not a placeholder
    init?(geometry: Geometry?) {
        guard let geometry = geometry else { return nil }
        guard let collaboration = geometry.features.first?.collaborations.first else {
            Logger.mapbox.error("Trying to assign geometry with no collaboration")
            return nil
        }
        guard collaboration.placeholder == false else {
            Logger.mapbox.error("Trying to assign geometry with a placeholder collaboration")
            return nil
        }
        guard case let .point(point) = geometry.geometry else {
            Logger.mapbox.error("Trying to assign non point geometry to PinView")
            return nil
        }
        id = geometry.id
        self.point = point
        self.collaboration = collaboration
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    /// Update geometry. Fails if geometry has different id than `self.id` or geometry is not a point
    func setGeometry(_ geometry: Geometry) {
        guard geometry.id == id else {
            Logger.mapbox.error("Trying to reuse PinView for different geometry")
            return
        }
        guard let collaboration = geometry.features.first?.collaborations.first else {
            Logger.mapbox.error("Trying to assign geometry with no collaboration")
            return
        }
        guard collaboration.placeholder == false else {
            Logger.mapbox.error("Trying to assign geometry with a placeholder collaboration")
            return
        }
        guard case let .point(point) = geometry.geometry else {
            Logger.mapbox.error("Trying to assign non point geometry to PinView")
            return
        }
        self.point = point
        self.collaboration = collaboration
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapped() {
        delegate?.pinViewTapped(self)
    }
}
