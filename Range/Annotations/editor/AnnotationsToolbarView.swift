import SwiftUI

struct AnnotationsToolbarView: View {
    @ObservedObject var model: AnnotationsEditorViewModel
    @State var pickingLineThickness: Bool = false
    @State var pickingColor: Bool = false
    @State var pickingTextFontSize: Bool = false

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

    private var lineThicknessButton: some View {
        Button(action: {
            pickingLineThickness = true
            pickingColor = false // hide the other picker if shown
            pickingTextFontSize = false
        }) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: 1000)
                    .frame(width: 30, height: model.currentLineThickness.toolbarWidth)
                    .foregroundColor(.Neutral_01))
        }
    }

    private var lineThicknessPicker: some View {
        VStack(spacing: 8) {
            ForEach(Annotations.LineThickness.allCases, id: \.rawValue) { thickness in
                Button(action: {
                    model.setCurrentLineThickness(thickness)
                    pickingLineThickness = false
                }) {
                    Circle()
                        .fill(thickness == model.currentLineThickness
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

    private var colorButton: some View {
        Button(action: {
            pickingLineThickness = false // hide the other picker if shown
            pickingColor = true
            pickingTextFontSize = false
        }) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .overlay(Circle()
                    .strokeBorder(Color.Neutral_01, lineWidth: 1)
                    .background(Circle().fill(Color(model.currentColor)))
                    .frame(width: 28, height: 28))
        }
    }

    private var colorPicker: some View {
        VStack(spacing: 8) {
            ForEach(Annotations.colors, id: \.hexString) { color in
                Button(action: {
                    model.setCurrentColor(color)
                    pickingColor = false
                }) {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 48, height: 48)
                        .overlay {
                            if color == model.currentColor {
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

    private var textFontSizeButton: some View {
        Button(action: {
            pickingLineThickness = false
            pickingColor = false
            pickingTextFontSize = true
        }) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "textformat")
                    .font(.system(size: model.currentTextFontSize.toolbarSize, weight: .bold))
                    .frame(width: 30, height: 10)
                    .foregroundColor(.Neutral_01))
        }
    }

    private var textFontSizePicker: some View {
        VStack(spacing: 8) {
            ForEach(Annotations.FontSize.allCases, id: \.rawValue) { fontSize in
                Button(action: {
                    model.setCurrentFontSize(fontSize)
                    pickingTextFontSize = false
                }) {
                    Circle()
                        .fill(fontSize == model.currentTextFontSize
                            ? Color.Neutral_01.opacity(0.2) : Color.clear)
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "textformat")
                                .font(.system(size: fontSize.toolbarSize, weight: .bold))
                                .foregroundColor(.Neutral_01)
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
                // helper variables to make the conditions below easier to read
                let annotationSelected = model.selectedAnnotation != nil
                let scribbleMode = model.scribbleMode
                let scribbleSelected = model.selectedAnnotation?.type == .scribble
                let textSelected = model.selectedAnnotation?.type == .text
                let arrowSelected = model.selectedAnnotation?.type == .arrow

                let showScribbleToolButton = scribbleMode || !annotationSelected || scribbleSelected
                let showTextToolButton = !scribbleMode && (!annotationSelected || textSelected)
                let showArrowToolButton = !scribbleMode && (!annotationSelected || arrowSelected)

                // The IFs below are bad... but we want to make sure that we only have one place
                // in code that adds any tool button, this way when it's kept visible when switching
                // modes, selecting annotations, etc (basically changing the toolbar layout) it'll be
                // properly animated to new place (instead of disappear and appear in new place)
                if showScribbleToolButton {
                    scribbleToolButton
                    if showArrowToolButton || showTextToolButton {
                        Spacer().frame(minWidth: 8, idealWidth: 32, maxWidth: 32)
                    }
                }
                // TODO: 1982
//                if showArrowToolButton {
//                    arrowToolButton
//                    if showTextToolButton {
//                        Spacer().frame(minWidth: 8, idealWidth: 32, maxWidth: 32)
//                    }
//                }
                if showTextToolButton { textToolButton }

                if scribbleMode || annotationSelected {
                    Spacer().frame(minWidth: 8, idealWidth: 40, maxWidth: 40)
                    if scribbleMode || scribbleSelected || textSelected {
                        // TODO: 1982 now it's line thickness ? reused for arrow and scribble...
                        lineThicknessButton.pickerPopup(isPresented: $pickingLineThickness) {
                            lineThicknessPicker
                        }
                    }
                    if textSelected {
                        textFontSizeButton.pickerPopup(isPresented: $pickingTextFontSize) {
                            textFontSizePicker
                        }
                    }
                    colorButton.pickerPopup(isPresented: $pickingColor) {
                        colorPicker
                    }
                }
                if annotationSelected {
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
