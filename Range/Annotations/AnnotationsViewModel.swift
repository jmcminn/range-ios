
import Foundation
import UIKit

/// Used to keep the state of the current photo annotation session.
/// Based on this state the AnnotationsToolbarView is rendered.
///
/// Achtung: Even if annotating multiple photos in a gallery, there's still 1 `AnnotationsViewModel` but there's many `Annotations`
///
class AnnotationsViewModel: ObservableObject {
    /// currently annotated page in photos gallery
    var currentAnnotations: Annotations?

    /// Is the scribble mode enabled
    @Published private(set) var scribbleMode: Bool = false

    func toggleScribbleMode() {
        scribbleMode.toggle()
        currentAnnotations?.setScribblingEnabled(scribbleMode)
    }
}
