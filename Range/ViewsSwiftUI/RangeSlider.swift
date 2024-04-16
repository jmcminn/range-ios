import SwiftUI

/// Custom slider used in annotations editor
///
/// Based on https://github.com/john-mueller/SwiftUI-Examples/tree/master/SwiftUI-Examples/VSlider
struct RangeSlider<V: BinaryFloatingPoint>: View {
    var value: Binding<V>
    var range: ClosedRange<V> = 0 ... 1
    var step: V.Stride?
    var onEditingChanged: (Bool) -> Void = { _ in }

    private let size: CGSize
    private let drawRadius: CGFloat = 13
    private let dragRadius: CGFloat = 25
    private let lineWidth: CGFloat = 3

    @State private var validDrag = false

    init(
        value: Binding<V>,
        in range: ClosedRange<V> = 0 ... 1,
        step: V.Stride? = nil,
        onEditingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.value = value
        guard let backgroundImage = UIImage(named: "slider") else {
            fatalError("image for slider not found")
        }
        size = backgroundImage.size

        if let step = step {
            self.step = step
            var newUpperbound = range.lowerBound
            while newUpperbound.advanced(by: step) <= range.upperBound {
                newUpperbound = newUpperbound.advanced(by: step)
            }
            self.range = ClosedRange(uncheckedBounds: (range.lowerBound, newUpperbound))
        } else {
            self.range = range
        }

        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("slider")

            // The filled portion of the slider
            Image("slider_filled")
                .frame(height: size.height - self.getKnobPoint().y, alignment: .bottom)
                .clipped()

            // Knob
            Circle()
                .frame(width: 2 * self.drawRadius, height: 2 * self.drawRadius)
                .position(self.getKnobPoint())
                .foregroundColor(Color.white)
                .shadow(radius: 2, y: 2)

            // Catches drag gesture
            Rectangle()
                .frame(minWidth: CGFloat(self.dragRadius))
                .foregroundColor(Color.white.opacity(0.001))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            self.validDrag = false
                            self.onEditingChanged(false)
                        }
                        .onChanged(self.handleDragged())
                )
        }
    }
}

extension RangeSlider {
    // the center point for knob
    private func getKnobPoint() -> CGPoint {
        let x = size.width / 2
        let location = value.wrappedValue - range.lowerBound
        let scale = V(2 * drawRadius - size.height) / (range.upperBound - range.lowerBound)
        let y = CGFloat(location * scale) + size.height - drawRadius
        return CGPoint(x: x, y: y)
    }

    private func handleDragged() -> (DragGesture.Value) -> Void {
        { drag in
            if drag.startLocation.distance(to: self.getKnobPoint()) < self.dragRadius, !self.validDrag {
                self.validDrag = true
                self.onEditingChanged(true)
            }

            if self.validDrag {
                let location = drag.location.y - size.height + self.drawRadius
                let scale = CGFloat(self.range.upperBound - self.range.lowerBound) /
                    (2 * self.drawRadius - size.height)
                let newValue = V(location * scale) + self.range.lowerBound
                let clampedValue = max(min(newValue, self.range.upperBound), self.range.lowerBound)

                if self.step != nil {
                    let step = V.zero.advanced(by: self.step!)
                    self.value.wrappedValue = round((clampedValue - self.range.lowerBound) / step) * step + self.range
                        .lowerBound
                } else {
                    self.value.wrappedValue = clampedValue
                }
            }
        }
    }
}

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}

#Preview {
    @State var someValue: CGFloat = 1

    return RangeSlider(value: $someValue, in: 1 ... 10)
}
