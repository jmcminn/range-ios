import UIKit

// adapted from: https://gist.github.com/micheltlutz/de304ce9559605792f30056b5b693fe3

extension UITableView {
    /// Adds background, selectedBackground and border so the table looks like the section is rounded. (like in grouped style)
    /// - Warning: the color is used as cgColor which means that it'll not automatically update on appearance change
    /// - Parameters:
    ///     - cell:
    ///     - indexPath
    ///     -  backgroundColor:
    ///     - borderColor:
    ///     - selectedBackgroundColor:
    ///     - horizontalPadding:                since this is used on plain UITableView we need to add some padding so it looks like grouped (and the cells don't touch the left/right bounds)
    func addBackgroundWithBorder(
        forCell cell: UITableViewCell,
        forRowAt indexPath: IndexPath,
        backgroundColor: UIColor,
        borderColor: UIColor,
        selectedBackgroundColor: UIColor,
        horizontalPadding: CGFloat = 16.0
    ) {
        let backgroundLayer = createRoundedLayer(
            forCell: cell,
            forRowAt: indexPath,
            cornerRadius: 12,
            horizontalPadding: horizontalPadding
        )
        backgroundLayer.strokeColor = borderColor.cgColor
        backgroundLayer.lineWidth = 1
        backgroundLayer.fillColor = backgroundColor.cgColor

        let backgroundView = UIView(frame: bounds)
        backgroundView.layer.insertSublayer(backgroundLayer, at: 0)
        backgroundView.backgroundColor = .clear
        cell.backgroundView = backgroundView

        let selectedBackgroundLayer = createRoundedLayer(
            forCell: cell,
            forRowAt: indexPath,
            cornerRadius: 12,
            horizontalPadding: horizontalPadding
        )
        selectedBackgroundLayer.strokeColor = borderColor.cgColor
        selectedBackgroundLayer.lineWidth = 1
        selectedBackgroundLayer.fillColor = selectedBackgroundColor.cgColor

        let selectedBackgroundView = UIView(frame: bounds)
        selectedBackgroundView.layer.insertSublayer(selectedBackgroundLayer, at: 0)
        selectedBackgroundView.backgroundColor = .clear
        cell.selectedBackgroundView = selectedBackgroundView

        cell.contentView.directionalLayoutMargins.leading = horizontalPadding
        cell.contentView.directionalLayoutMargins.trailing = horizontalPadding
    }

    private func createRoundedLayer(
        forCell cell: UITableViewCell,
        forRowAt indexPath: IndexPath,
        cornerRadius: CGFloat,
        horizontalPadding: CGFloat
    ) -> CAShapeLayer {
        let layer = CAShapeLayer()
        let pathRef = CGMutablePath()

        if indexPath.row == 0, indexPath.row == numberOfRows(inSection: indexPath.section) - 1 {
            // this is the only row in section:
            pathRef.__addRoundedRect(
                transform: nil,
                // inset - otherwise the border is clipped
                rect: cell.bounds.insetBy(dx: horizontalPadding + 0.5, dy: 0.5),
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius
            )
        } else if indexPath.row == 0 {
            // additionally inset the first row top otherwise it's clipped
            let bounds: CGRect = cell.bounds
                .inset(by: UIEdgeInsets(top: 0.5,
                                        left: horizontalPadding + 0.5,
                                        bottom: 0,
                                        right: horizontalPadding + 0.5))
            pathRef.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            pathRef.addArc(tangent1End: CGPoint(x: bounds.minX, y: bounds.minY),
                           tangent2End: CGPoint(x: bounds.midX, y: bounds.minY),
                           radius: cornerRadius)

            pathRef.addArc(tangent1End: CGPoint(x: bounds.maxX, y: bounds.minY),
                           tangent2End: CGPoint(x: bounds.maxX, y: bounds.midY),
                           radius: cornerRadius)
            pathRef.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            pathRef.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        } else if indexPath.row == numberOfRows(inSection: indexPath.section) - 1 {
            let bounds: CGRect = cell.bounds.insetBy(dx: horizontalPadding + 0.5, dy: 0)
            pathRef.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            pathRef.addArc(tangent1End: CGPoint(x: bounds.minX, y: bounds.maxY),
                           tangent2End: CGPoint(x: bounds.midX, y: bounds.maxY),
                           radius: cornerRadius)

            pathRef.addArc(tangent1End: CGPoint(x: bounds.maxX, y: bounds.maxY),
                           tangent2End: CGPoint(x: bounds.maxX, y: bounds.midY),
                           radius: cornerRadius)
            pathRef.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            pathRef.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY))
        } else {
            let bounds: CGRect = cell.bounds.insetBy(dx: horizontalPadding + 0.5, dy: 0)
            pathRef.addRect(bounds)
        }

        layer.path = pathRef

        return layer
    }
}
