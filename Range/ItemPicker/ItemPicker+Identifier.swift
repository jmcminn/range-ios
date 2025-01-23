import Foundation
import RealmSwift
import UIKit

/// Convenience extension for creating an ItemPickerViewModel for project canvases
extension ItemPickerViewModel {
    convenience init(collaborationIdentifiers collaborations: [Collaboration], model: ProjectModel, multiselect: Bool) {
        let allItems: [ItemPickerItem] = collaborations.compactMap {
            guard let collaborationIdentifier = model.collaborationIdentifier($0) else { return nil }
            return ItemPickerItem(id: $0.id, name: collaborationIdentifier, marked: false)
        }
        .sorted { item0, item1 in item0.name < item1.name }

        self.init(allItems: Array(allItems), multiselect: multiselect)
    }
}

extension SelectedItemPickerItemsView {
    convenience init(identifiersViewForModel viewModel: ItemPickerViewModel) {
        self.init(viewModel: viewModel, config: .init(editCellVariant: .editID))
    }
}

extension ItemPickerCardViewController {
    convenience init(identifierPickerForModel viewModel: ItemPickerViewModel) {
        self.init(
            icon: UIImage(systemName: "number.circle"),
            title: "ID",
            searchPlaceholderText: "Search for an ID...",
            viewModel: viewModel,
            selectedItemsViewConfig: .init()
        )
    }
}
