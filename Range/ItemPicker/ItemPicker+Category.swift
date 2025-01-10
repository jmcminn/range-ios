import Foundation
import UIKit

/// Convenience extension for creating an ItemPickerViewModel for project categories
extension ItemPickerViewModel {
    convenience init(categoryPickerForModel model: ProjectModel, multiselect: Bool) {
        let allItems = model.mainRealm.objects(Category.self)
            .sorted(by: Category.uiSortingOrder)
            .map { ItemPickerItem(id: $0.id, name: $0.name, icon: $0.icon, marked: false) }
        self.init(allItems: allItems, multiselect: multiselect)
    }
}

extension SelectedItemPickerItemsView {
    convenience init(categoriesViewForModel viewModel: ItemPickerViewModel) {
        self.init(
            viewModel: viewModel,
            config: .init(editCellVariant: .editCategory, itemIconSystemName: nil)
        )
    }
}

extension ItemPickerCardViewController {
    convenience init(categoryPickerForModel viewModel: ItemPickerViewModel) {
        self.init(
            icon: UIImage(systemName: "hammer"),
            title: "Category Selector",
            searchPlaceholderText: "Search for a category...",
            viewModel: viewModel,
            selectedItemsViewConfig: .init()
        )
    }
}
