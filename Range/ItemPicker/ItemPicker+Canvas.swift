import Foundation
import UIKit

/// Convenience extension for creating an ItemPickerViewModel for project canvases
extension ItemPickerViewModel {
    convenience init(canvasPickerForModel model: ProjectModel, multiselect: Bool) {
        let allItems = model.sortedCanvases.map {
            ItemPickerItem(id: $0.id, name: $0.name, marked: !$0.geometries.isEmpty)
        }
        self.init(allItems: allItems, multiselect: multiselect)
    }
}

extension SelectedItemPickerItemsView {
    convenience init(canvasesViewForModel viewModel: ItemPickerViewModel) {
        self.init(
            viewModel: viewModel,
            config: .init(editCellVariant: .editCanvas, itemIconSystemName: "square.3.layers.3d")
        )
    }
}

extension ItemPickerCardViewController {
    convenience init(canvasPickerForModel viewModel: ItemPickerViewModel) {
        self.init(
            icon: UIImage(systemName: "square.3.layers.3d"),
            title: "Canvas Selector",
            searchPlaceholderText: "Search for a canvas...",
            viewModel: viewModel,
            selectedItemsViewConfig: .init(itemIconSystemName: "square.3.layers.3d")
        )
    }
}
