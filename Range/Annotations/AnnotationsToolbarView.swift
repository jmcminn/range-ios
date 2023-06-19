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

    private var scribbleThicknessButton: some View {
        Button(action: {}) {
            Circle()
                .strokeBorder(Color.Neutral_10, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_10))
                .frame(width: 48, height: 48)
                // TODO: 1290 this should be a view with some thickness depending on the view model
                .overlay(Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.Neutral_01))
        }.buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(action: { model.deleteAnnotation() }) {
            Circle()
                .strokeBorder(Color.Neutral_10, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_10))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "trash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.Red_03))
        }.buttonStyle(.plain)
    }

    private var unselectButton: some View {
        Button(action: { model.unselectAnnotation() }) {
            Circle()
                .strokeBorder(Color.Neutral_10, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_10))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.Neutral_01))
        }.buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 4) {
            scribbleButton
            if model.selectedAnnotation != nil {
                Spacer(minLength: 40)
                // TODO: 1290
//                scribbleThicknessButton
                deleteButton
                unselectButton
            }
        }
        .padding(16)
        .background(background)
        .padding(.horizontal, 16)
        .animation(
            .default,
            value: model.selectedAnnotation
        )
    }
}

struct AnnotationsToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationsToolbarView(model: AnnotationsViewModel())
    }
}
