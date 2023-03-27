import Foundation
import UIKit

/// A view drawing a grid
class GridView: UIView {
    /// Draw a line every `gridWidth` points
    fileprivate var gridWidth = 10.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .dynamic(.Neutral_09)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_: CGRect) {
        /// the path with grid
        let path = UIBezierPath()
        /// the path with more prominent lines (every 10th)
        let prominentPath = UIBezierPath()

        path.lineWidth = 1
        prominentPath.lineWidth = 1

        // start from the grid center and draw the grid to the left/right/top/bottom, making
        // it more prominent every 10th line

        // vertical lines
        let numOfVerticalLines = Int(bounds.width / gridWidth / 2)
        for index in 0 ... numOfVerticalLines {
            let p = index % 10 == 0 ? prominentPath : path
            // draw only 1 line in the middle and then draw to the left and right
            let xPositions: [CGFloat] = index == 0
                ? [bounds.midX]
                : [bounds.midX - CGFloat(index) * gridWidth, bounds.midX + CGFloat(index) * gridWidth]
            for x in xPositions {
                let start = CGPoint(x: x, y: 0)
                let end = CGPoint(x: x, y: bounds.height)
                p.move(to: start)
                p.addLine(to: end)
            }
        }

        // horizontal lines
        let numOfHorizontalLines = Int(bounds.height / gridWidth / 2)
        for index in 0 ... numOfHorizontalLines {
            let p = index % 10 == 0 ? prominentPath : path
            // draw only 1 line in the middle and then draw to the top and bottom
            let yPositions: [CGFloat] = index == 0
                ? [bounds.midY]
                : [bounds.midY - CGFloat(index) * gridWidth, bounds.midY + CGFloat(index) * gridWidth]
            for y in yPositions {
                let start = CGPoint(x: 0, y: y)
                let end = CGPoint(x: bounds.width, y: y)
                p.move(to: start)
                p.addLine(to: end)
            }
        }

        // Close the and draw the paths
        path.close()
        UIColor.dynamic(.Neutral_08).setStroke()
        path.stroke()

        prominentPath.close()
        UIColor.dynamic(.Neutral_07).setStroke()
        prominentPath.stroke()
    }
}
