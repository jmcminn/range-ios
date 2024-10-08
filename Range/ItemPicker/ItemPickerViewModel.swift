import Algorithms
import Foundation
import RealmSwift

/// View model for ItemPicker item
class ItemPickerItem: NSObject, Codable {
    let id: String
    @objc let name: String
    let marked: Bool
    /// for searching we store a version of string that is diacriticInsensitive and caseInsensitive
    let searchName: String
    @objc fileprivate(set) dynamic var selected: Bool = false

    /// Initializer for existing users
    /// - Parameters:
    ///   - id: id
    ///   - name: name of the user
    ///   - marked: whether the item is marked with a pink dot
    init(id: String, name: String, marked: Bool) {
        self.id = id
        self.name = name
        self.marked = marked
        searchName = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    /// equatable to check for id only
    static func == (lhs: ItemPickerItem, rhs: ItemPickerItem) -> Bool {
        lhs.id == rhs.id
    }

    override var description: String {
        "'\(name)'[\(id.prefix(8))]"
    }
}

/// View model for list of ItemPickerItem(s)
class ItemPickerViewModel: NSObject {
    /// whether it's a multi or single select model
    let multiselect: Bool
    /// all item whether selected or not
    private(set) var allItems: [ItemPickerItem]
    /// For fast lookup by id
    private var allItemsIndex: [String: ItemPickerItem]
    /// a subset of all items storing selected ones in order they were being selected
    private(set) var selectedItems: [ItemPickerItem] = []
    /// filter to be used on `allItems` to derive `filteredItems`
    private(set) var filterString: String = ""
    /// a subset of all items matching the current filter in the order as in `allItems`
    private(set) var filteredItems: [ItemPickerItem] = []

    /// Allows for multiple delegates
    private var delegates = NSHashTable<ItemPickerViewModelDelegate>.weakObjects()

    init(allItems: [ItemPickerItem], multiselect: Bool) {
        self.multiselect = multiselect
        self.allItems = allItems

        allItemsIndex = Dictionary(uniqueKeysWithValues: zip(allItems.map(\.id), allItems))

        super.init()

        filteredItems = allItems
    }

    /// Add delegate
    /// No option for removal as delegates are stored weakly
    func addDelegate(_ delegate: ItemPickerViewModelDelegate) {
        delegates.add(delegate)
    }

    /// Mark item with given id as selected/deselected and notify delegates
    /// If item with given id is not present it's ignored
    func set(itemWithId id: String, selected: Bool) {
        // find item with matching id in this view model tags
        guard let item = allItemsIndex[id] else { return }
        guard item.selected != selected else { return }

        // store ids to unselect at the end (after selection)
        // the unselection is done after selection so switching selection doesn't produce
        // a temporary empty selection (which doesn't work nicely with the animations
        // based on the callbacks from model).
        // TODO: Ideally all the selections/unselections  would be propagated in 1 delegate call (kind of transactional)
        let idsToUnselect: [String]?
        if selected {
            if multiselect {
                // no unselection in multiselect
                idsToUnselect = nil
            } else {
                // for single selection we unselect the previously selected
                idsToUnselect = selectedItems.map(\.id)
            }
        } else {
            idsToUnselect = nil
        }

        item.selected = selected
        if item.selected {
            // insert as last item in selected list
            selectedItems.append(item)
            let insertIndex = selectedItems.count - 1
            delegates.allObjects.forEach {
                $0.itemPickerViewModel?(self, item: item, selected: true, indexInSelectedItems: insertIndex)
            }
        } else {
            if let deleteIndex = selectedItems.firstIndex(of: item) {
                selectedItems.remove(at: deleteIndex)
                delegates.allObjects.forEach {
                    $0.itemPickerViewModel?(self, item: item, selected: false, indexInSelectedItems: deleteIndex)
                }
            }
        }

        if let idsToUnselect = idsToUnselect {
            idsToUnselect.forEach { self.set(itemWithId: $0, selected: false) }
        }
    }

    /// Unselect all selected items
    func clearSelection() {
        let selectedIds = selectedItems.map(\.id)
        selectedIds.forEach { self.set(itemWithId: $0, selected: false) }
    }

    /// filter `allItems` by given String and store results in `filteredItems`
    func filter(by filterString: String) {
        self.filterString = filterString
        let filterStringTrimmed = filterString.trimmingCharacters(in: .whitespacesAndNewlines)
        // remove diacritics and make it lowercase
        let filterTerm = filterStringTrimmed
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        // split by whitespace to multiple terms
        let filterTerms = filterTerm.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        // item matches if it contains all the filterTerms
        filteredItems = allItems.filter { item in
            // has to contain all of the search terms
            filterTerms.allSatisfy { item.searchName.contains($0) }
        }
        delegates.allObjects.forEach { $0.itemPickerViewModelFiltered?(self) }
    }
}

/// Delegate for `ItemPickerViewModel`
///
/// see `SearchViewDelegate` for why it's @objc protocol
@objc protocol ItemPickerViewModelDelegate: AnyObject {
    /// notifies that the given user was selected/deselected
    /// - Parameters:
    ///     - viewModel
    ///     - item selected item
    ///     - selected: selected or deselected
    ///     - indexInSelectedItems: it's new index in the `selectedItems`
    @objc optional func itemPickerViewModel(
        _ viewModel: ItemPickerViewModel,
        item: ItemPickerItem,
        selected: Bool,
        indexInSelectedItems: Int
    )

    /// notifies that a filter was applied (or removed) from the viewModel.
    @objc optional func itemPickerViewModelFiltered(_ viewModel: ItemPickerViewModel)
}
