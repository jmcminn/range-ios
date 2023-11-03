import SwiftUI

struct AnnotationsToolbarView: View {
    @ObservedObject var model: AnnotationsEditorViewModel
    @State var pickingScribbleThickness: Bool = false
    @State var pickingScribbleColor: Bool = false

    /// background for toolbar buttons
    private var panelBackground: some View {
        let rectangle = RoundedRectangle(cornerRadius: 40)
        // cannot add fill and stroke to rectangle, so we need rectange with background rectangle
        return rectangle
            .stroke(Color.Neutral_07, lineWidth: 1)
            .background(rectangle.fill(Color.Neutral_10))
    }

    /// blurred background for toolbar buttons
    private var blurredPanelBackground: some View {
        let rectangle = RoundedRectangle(cornerRadius: 40)
        // cannot add fill and stroke to rectangle, so we need rectange with background rectangle
        return rectangle
            .stroke(Color.Neutral_07, lineWidth: 1)
            .background(
                VisualEffectView(effect: UIBlurEffect(style: .dark))
                    .clipShape(rectangle)
            )
    }

    private var scribbleToolButton: some View {
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

    private var textToolButton: some View {
        Button(action: { model.insertTextAnnotation() }) {
            Circle()
                .strokeBorder(Color.Neutral_07, lineWidth: 1)
                .background(Circle().fill(Color.Neutral_09))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "character.textbox")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.Neutral_01))
        }.buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(action: { model.deleteAnnotation() }) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "trash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.Red_03))
        }
    }

    private var unselectButton: some View {
        Button(action: { model.unselectAnnotation() }) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.Neutral_01))
        }
    }

    private var scribbleThicknessButton: some View {
        Button(action: {
            pickingScribbleThickness = true
            pickingScribbleColor = false // hide the other picker if shown
        }) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: 1000)
                    .frame(width: 30, height: model.currentScribbleThickness.toolbarWidth)
                    .foregroundColor(.Neutral_01))
        }
    }

    private var scribbleThicknessPicker: some View {
        VStack(spacing: 8) {
            ForEach(Annotations.ScribbleThickness.allCases, id: \.rawValue) { thickness in
                Button(action: {
                    model.setCurrentScribbleThickness(thickness)
                    pickingScribbleThickness = false
                }) {
                    Circle()
                        .fill(thickness == model.currentScribbleThickness
                            ? Color.Neutral_01.opacity(0.2) : Color.clear)
                        .frame(width: 48, height: 48)
                        .overlay {
                            RoundedRectangle(cornerRadius: 1000)
                                .frame(width: 30, height: thickness.toolbarWidth)
                                .foregroundColor(.Neutral_01)
                        }
                }
            }
        }
        .padding(8)
        .background(blurredPanelBackground)
    }

    private var scribbleColorButton: some View {
        Button(action: {
            pickingScribbleThickness = false // hide the other picker if shown
            pickingScribbleColor = true
        }) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .overlay(Circle()
                    .strokeBorder(Color.Neutral_01, lineWidth: 1)
                    .background(Circle().fill(Color(model.currentScribbleColor)))
                    .frame(width: 28, height: 28))
        }
    }

    private var scribbleColorPicker: some View {
        VStack(spacing: 8) {
            ForEach(Annotations.scribbleColors, id: \.hexString) { color in
                Button(action: {
                    model.setCurrentScribbleColor(color)
                    pickingScribbleColor = false
                }) {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 48, height: 48)
                        .overlay {
                            if color == model.currentScribbleColor {
                                Circle()
                                    .strokeBorder(Color.Neutral_01, lineWidth: 6)
                                    .background(Circle().fill(Color(color)))
                                    .frame(width: 40, height: 40)
                            } else {
                                Circle()
                                    .strokeBorder(Color.Neutral_01, lineWidth: 1)
                                    .background(Circle().fill(Color(color)))
                                    .frame(width: 28, height: 28)
                            }
                        }
                }
            }
        }
        .padding(8)
        .background(blurredPanelBackground)
    }

    var body: some View {
        VStack {
            HStack(spacing: 4) {
                scribbleToolButton
                if model.selectedAnnotation == nil, !model.scribbleMode {
                    Spacer().frame(minWidth: 8, idealWidth: 32, maxWidth: 32)
                    textToolButton
                }
                if model.selectedAnnotation != nil || model.scribbleMode {
                    Spacer().frame(minWidth: 8, idealWidth: 40, maxWidth: 40)
                    scribbleThicknessButton.pickerPopup(isPresented: $pickingScribbleThickness) {
                        scribbleThicknessPicker
                    }
                    scribbleColorButton.pickerPopup(isPresented: $pickingScribbleColor) {
                        scribbleColorPicker
                    }
                }
                if model.selectedAnnotation != nil {
                    Spacer().frame(width: 8)
                    Divider().frame(width: 1, height: 48).overlay(Color.Neutral_07)
                    Spacer().frame(width: 8)
                    deleteButton
                    unselectButton
                }
            }
            .padding(16)
            .background(panelBackground)
            .animation(.default, value: model.selectedAnnotation)
            .animation(.default, value: model.scribbleMode)
        }
        .disabled(!model.editingEnabled)
    }
}

struct AnnotationsToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        AnnotationsToolbarView(model: AnnotationsEditorViewModel())
    }
}

/// View modifier to wrap the code related to presenting a picker over a toolbar button
struct PickerPopup<T: View>: ViewModifier {
    let popup: T
    let isPresented: Binding<Bool>

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> T) {
        self.isPresented = isPresented
        popup = content()
    }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented.wrappedValue {
                    popup
                        .offset(y: 8) // to show the bottom picker button over the toolbar button (picker has padding = 8)
                }
            }
            .zIndex(1)
            .animation(.default, value: isPresented.wrappedValue)
    }
}

extension View {
    /// idiomatic way to add picker popup (instead of using modifier in the swift ui code
    func pickerPopup<T: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> T) -> some View {
        modifier(PickerPopup(isPresented: isPresented, content: content))
    }
}
