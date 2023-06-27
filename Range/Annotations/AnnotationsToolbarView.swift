import SwiftUI

struct AnnotationsToolbarView: View {
    @ObservedObject var model: AnnotationsViewModel

    /// background for toolbar buttons
    private var panelBackground: some View {
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
                .overlay(RoundedRectangle(cornerRadius: 1000)
                    .frame(width: 30, height: model.currentScribbleThickness.toolbarWidth)
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

    // TODO: 1290
    private var scribbleThicknessSelector: some View {
        VStack(spacing: 8) {
            ForEach(Annotations.ScribbleThickness.allCases, id: \.rawValue) { thickness in
                Button(action: {}) {
                    Circle()
                        .strokeBorder(Color.Neutral_10, lineWidth: 1)
                        .background(Circle().fill(Color.Neutral_10))
                        .frame(width: 48, height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 1000)
                            .frame(width: 30, height: thickness.toolbarWidth)
                            .foregroundColor(.Neutral_01))
                }.buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(panelBackground)
    }

    var body: some View {
        VStack {
            HStack(spacing: 4) {
                scribbleButton
                if model.selectedAnnotation != nil || model.scribbleMode {
                    Spacer(minLength: 40)
                    scribbleThicknessButton.overlay {
                        // TODO: 1290
//                        scribbleThicknessSelector
                    }
                }
                if model.selectedAnnotation != nil {
                    Divider().frame(width: 1, height: 48).overlay(Color.Neutral_07)
                    deleteButton
                    unselectButton
                }
            }
            .padding(16)
            .background(panelBackground)
            .animation(
                .default,
                value: model.selectedAnnotation
            )
        }
    }
}

struct AnnotationsToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationsToolbarView(model: AnnotationsViewModel())
    }
}
