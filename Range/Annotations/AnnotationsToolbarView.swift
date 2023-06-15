import SwiftUI

struct AnnotationsToolbarView: View {
    @ObservedObject var model: AnnotationsViewModel

    /// background for toolbar buttons
    private var background: some View {
        let rectangle = RoundedRectangle(cornerRadius: 40)
        // cannot add fill and stroke to rectangle, so we need rectange with background rectangle
        return rectangle
            .stroke(Color.Neutral_07, lineWidth: 1)
            .background(rectangle.fill(Color.Neutral_10))
    }

    private var scribbleButton: some View {
        Button(action: { model.toggleScribbleMode() }) {
            Circle()
                .strokeBorder(model.scribbleMode ? Color.Special_02 : Color.Neutral_07, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_09))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "scribble")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(model.scribbleMode ? .Special_02 : .Neutral_01))
        }.buttonStyle(.plain)
    }

    var body: some View {
        HStack {
            scribbleButton
        }
        .padding(16)
        .background(background)
    }
}

struct AnnotationsToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationsToolbarView(model: AnnotationsViewModel())
    }
}
