import SwiftUI

struct CreateProjectStep2View: View {
    @ObservedObject var model: CreateProjectViewModel
    let showTypeSelectorAction: () -> Void
    let showTagSourceSelectorAction: () -> Void
    let whatAreProjectTagsAction: () -> Void
    let backAction: () -> Void
    let createProjectAction: () -> Void
    @FocusState private var focusedField: String?

    private var divider: some View {
        Divider()
            .frame(height: 1)
            .background(Color.dynamic(.Neutral_07))
    }

    private func label(iconSystemName: String? = nil, _ text: String) -> some View {
        HStack(spacing: 2) {
            if let iconSystemName {
                Image(systemName: iconSystemName)
            }
            Text(text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color.dynamic(.Neutral_05))
        .font(.subheadline.bold())
        .padding(.leading, 16).padding(.vertical, 12)
    }

    private var nameField: some View {
        TextField(
            "Project name",
            text: $model.name,
            prompt: Text("Give your project a name...").foregroundColor(.dynamic(.Neutral_05))
        )
        .foregroundColor(.dynamic(.Neutral_04))
        .textInputAutocapitalization(.words)
        .textContentType(.name)
        .submitLabel(.next)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.dynamic(.Neutral_09))
        .focused($focusedField, equals: "name")
        .onSubmit {
            focusedField = "description"
        }
    }

    private var descriptionField: some View {
        let textField: TextField<Text>
        if #available(iOS 16.0, *) {
            // multiline vertically expanding textField for iOS 16
            textField = TextField(
                "Project description",
                text: $model.description,
                prompt: Text("Give your project a description...").foregroundColor(.dynamic(.Neutral_05)),
                axis: .vertical
            )
        } else {
            // For iOS 15 we use the one line horizontally scrollable field.
            // We can instead use the TextEditor but it has it's own problems (doesn't adapt
            // to text height when initially shown)
            textField = TextField(
                "Project description",
                text: $model.description,
                prompt: Text("Give your project a description...").foregroundColor(.dynamic(.Neutral_05))
            )
        }

        return textField
            .foregroundColor(.dynamic(.Neutral_04))
            .textInputAutocapitalization(.sentences)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(Color.dynamic(.Neutral_09))
            .focused($focusedField, equals: "description")
            .onSubmit {
                focusedField = nil
            }
            .toolbar {
                // we need a keyboard "Done" button as the multiline textField will interpret 'enter'
                // key as the new line
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Done") {
                        focusedField = nil
                    }
                    .foregroundStyle(Color.dynamic(.Neutral_01))
                }
            }
    }

    private var typeField: some View {
        DropdownButton(
            placeholderText: "Select a project type...",
            font: .body,
            text: $model.typeName,
            clicked: {
                focusedField = nil
                showTypeSelectorAction()
            }
        )
        .padding(.horizontal, 16)
        .background(Color.dynamic(.Neutral_09))
    }

    private var tagsField: some View {
        DropdownButton(
            placeholderText: "Start from scratch",
            font: .body,
            text: $model.tagSourceName,
            clicked: {
                focusedField = nil
                showTagSourceSelectorAction()
            }
        )
        .padding(.horizontal, 16)
        .background(Color.dynamic(.Neutral_09))
    }

    private var tagsFootnote: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(
                "Populate your projects tags using one of your existing projects, or start from scratch and add new tags as you go."
            )
            .font(.footnote)
            .foregroundStyle(Color.dynamic(.Neutral_05))

            Button(action: whatAreProjectTagsAction) {
                Text("What are project tags?")
                    .font(.footnote)
                    .underline()
            }
            .foregroundColor(.Primary_Blue_04)
        }
        .padding(16)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                label("Name")
                divider
                nameField
                divider

                label("Description")
                divider
                descriptionField
                divider

                label("Type")
                divider
                typeField
                divider

                label(iconSystemName: "tag", "Tags")
                divider
                tagsField
                divider
                tagsFootnote
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack {
                    BackButton(callback: backAction)
                    Spacer()
                }
                HStack(alignment: .center) {
                    Text("Step 2: ").foregroundColor(.dynamic(.Neutral_05)) +
                        Text("Project Detail").foregroundColor(.dynamic(.Neutral_04))
                }
                .font(.subheadline.bold())
            }
            .padding(.bottom, 4)
            .background(Color.dynamic(.Neutral_09))
            divider

            form

            // only show the bottom bar if the keyboard is not visible
            if focusedField == nil {
                divider
                HStack(spacing: 16) {
                    Button("Back", action: backAction)
                        .buttonStyle(._gray)
                    Button("Create Project", action: createProjectAction)
                        .buttonStyle(._blue)
                        .disabled(model.name.isEmpty || model.typeId == nil)
                }
                .padding(16)
                .background(Color.dynamic(.Neutral_10))
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    CreateProjectStep2View(
        model: CreateProjectViewModel(),
        showTypeSelectorAction: {},
        showTagSourceSelectorAction: {},
        whatAreProjectTagsAction: {},
        backAction: {},
        createProjectAction: {}
    )
}

// iOS 15 compatible TextEditor based solution for description text view
//        return ZStack {
//            // Let's always use the TextEditor (we could use multiline TextField when on iOS 16
//            // https://stackoverflow.com/a/60039382 but TextEditor works fine too, so let's not
//            // duplicate the code for now)
//            TextEditor(text: $model.description)
//                .withHiddenScrollContentBackground()
//                .padding(.horizontal, 11)
//                .padding(.vertical, 6)
//                .focused($focusedField, equals: "description")
//                .textInputAutocapitalization(.sentences)
//            if model.description.isEmpty {
//                Text("Give your project a description...")
//                    .foregroundColor(.dynamic(.Neutral_05))
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.horizontal, 16)
//                    .onTapGesture {
//                        focusedField = "description"
//                    }
//            }
//        }
//        .frame(minHeight: 48)
//        .background(Color.dynamic(.Neutral_09))
///// A view modifier that hides the scrollContentBackground when on iOS 16 and does nothing if below.
///// This is required to clear the background color of TextEditor on iOS 16
// struct WithHiddenScrollContentBackground: ViewModifier {
//    func body(content: Content) -> some View {
//        if #available(iOS 16.0, *) {
//            content.scrollContentBackground(.hidden)
//        } else {
//            content
//        }
//    }
// }
//
// extension View {
//    func withHiddenScrollContentBackground() -> some View {
//        modifier(WithHiddenScrollContentBackground())
//    }
// }
