import Foundation
import Realm
import RealmSwift
import UIKit

/// Convenience extension for creating an ItemPickerViewModel for project canvases
extension ItemPickerViewModel {
    convenience init(taskIdentifiersViewModel model: ProjectModel, multiselect: Bool) {
        let tasks: [Collaboration] = Array(model.mainRealm.objects(Collaboration.self)
            .where { (c: Query<Collaboration>) -> Query<Bool> in
                c.placeholder == false && c.status != nil // only tasks
            })

        let allItems: [ItemPickerItem] = tasks.compactMap {
            guard let collaborationIdentifier = model.collaborationIdentifier($0) else { return nil }
            return ItemPickerItem(id: $0.id, name: collaborationIdentifier)
        }
        self.init(allItems: Array(allItems), multiselect: multiselect)
    }
}

extension SelectedItemPickerItemsView {
    convenience init(identifiersViewForModel viewModel: ItemPickerViewModel) {
        self.init(viewModel: viewModel, config: .init(editCellVariant: .editID))
    }
}

// extension ItemPickerCardViewController {
//    convenience init(canvasPickerForModel viewModel: ItemPickerViewModel) {
//        self.init(
//            icon: UIImage(systemName: "square.3.layers.3d"),
//            title: "Canvas",
//            searchPlaceholderText: "Search for a canvas...",
//            viewModel: viewModel,
//            selectedItemsViewConfig: .init(itemIconSystemName: "square.3.layers.3d")
//        )
//    }
// }
