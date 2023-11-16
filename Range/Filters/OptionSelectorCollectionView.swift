import Foundation
import UIKit

/// Collection view presenting multiple options in a tag-like manner (blue pills).
/// Initially no option is selected. Whenever the option is selected its action handler is run and the previous option is unselected in the UI.
class OptionSelectorCollectionView: UIView {
    private let collectionView: UICollectionView
    private let options: [ActionItem]
    var selectedItem: Int?

    init(options: [ActionItem]) {
        self.options = options
        let layout = LeftAlignedCollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0 // the cells have spacing built-in for bigger tap area
        layout.minimumLineSpacing = 0 // the cells have spacing built-in for bigger tap area
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: 16 - OptionSelectorCollectionViewCell.cellContentInset,
            bottom: 0,
            right: 16 - OptionSelectorCollectionViewCell.cellContentInset
        )
        collectionView = SelfSizingCollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: .zero)

        addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        collectionView.register(OptionSelectorCollectionViewCell.self, forCellWithReuseIdentifier: "OptionCell")
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collectionView.backgroundColor = backgroundColor
        collectionView.collectionViewLayout.invalidateLayout()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        collectionView.reloadData()
    }
}

extension OptionSelectorCollectionView: UICollectionViewDelegate {
    /// Mark new item as selected, run its handler and unselect the previous one
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item != selectedItem else { return }
        let previousSelectedItem = selectedItem
        selectedItem = indexPath.item
        (collectionView.cellForItem(at: indexPath) as? OptionSelectorCollectionViewCell)?
            .setOption(options[indexPath.item].title ?? "", selected: true)
        if let previousSelectedItem = previousSelectedItem {
            (collectionView.cellForItem(at: IndexPath(item: previousSelectedItem,
                                                      section: 0)) as? OptionSelectorCollectionViewCell)?
                .setOption(options[previousSelectedItem].title ?? "", selected: false)
        }
        options[indexPath.item].handler?()
    }
}

extension OptionSelectorCollectionView: UICollectionViewDelegateFlowLayout {
    /// size the items based on the text width and text margins
    func collectionView(_: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let name = options[indexPath.item].title ?? ""
        let nameFont = UIFont.preferredFont(forTextStyle: .footnote)
        let nameSize = name.size(withAttributes: [NSAttributedString.Key.font: nameFont])
        return CGSize(
            width: nameSize.width + 2 *
                (OptionSelectorCollectionViewCell.textToBorderHorizontalPadding +
                    OptionSelectorCollectionViewCell.cellContentInset),
            height: max(40, nameSize.height + 2 *
                (OptionSelectorCollectionViewCell.textToBorderVerticalPadding +
                    OptionSelectorCollectionViewCell.cellContentInset))
        )
    }
}

extension OptionSelectorCollectionView: UICollectionViewDataSource {
    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        options.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OptionCell",
                                                      for: indexPath) as! OptionSelectorCollectionViewCell
        cell.setOption(options[indexPath.item].title ?? "", selected: indexPath.item == selectedItem)
        return cell
    }
}
