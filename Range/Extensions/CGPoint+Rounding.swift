//

import Foundation

extension CGPoint {
    /// Rounds the both coordinates to decimal places value
    func _rounded(toPlaces places:Int) -> CGPoint {
        return CGPoint(
            x: Double(x)._rounded(toPlaces: places),
            y: Double(y)._rounded(toPlaces: places)
        )
    }
}
