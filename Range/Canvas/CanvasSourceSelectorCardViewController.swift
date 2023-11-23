import Foundation
import UIKit

/// Card view controller presenting a list of canvas sources to choose from.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CanvasSourceSelectorCardViewController: SheetCardViewController {
    let canvasSources: [CanvasSource]
    private let selectedCanvasSource: CanvasSource?
    private let tableView = UITableView(frame: .zero, style: .plain)

    var onCanvasSourceSelected: ((CanvasSource) -> Void)?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                         title of the card
    ///     - canvasSources:      canvasSources to show in the selector
    init(
        title: String,
        canvasSources: [CanvasSource],
        selectedCanvasSource: CanvasSource?,
        onCanvasSourceSelected: ((CanvasSource) -> Void)? = nil
    ) {
        self.canvasSources = canvasSources
        self.selectedCanvasSource = selectedCanvasSource
        super.init(icon: UIImage(systemName: "map"), title: title)
        self.onCanvasSourceSelected = onCanvasSourceSelected
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupTableView()
        tableView.reloadData()
        containerView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(sheetHeaderView.snp.bottom)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = view.backgroundColor
        tableView.tableHeaderView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.tableFooterView =
            UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNormalMagnitude))
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(CanvasSourceTableViewCell.self, forCellReuseIdentifier: "CanvasSourceCell")
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // update the border color for cells
        tableView.reloadData()
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + tableView.contentSize.height + 16.0
        }
        return baseHeight
    }

    override func drivingScrollView() -> UIScrollView? {
        tableView
    }
}

extension CanvasSourceSelectorCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        canvasSources.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "CanvasSourceCell",
            for: indexPath
        ) as! CanvasSourceTableViewCell
        let canvasSource = canvasSources[indexPath.row]
        cell.setCanvasSource(canvasSource, selected: canvasSource == selectedCanvasSource)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamic(.Neutral_09),
            borderColor: .dynamic(.Neutral_07),
            selectedBackgroundColor: .dynamic(.Neutral_08)
        )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let canvasSource = canvasSources[indexPath.row]
        dismissCard()
        onCanvasSourceSelected?(canvasSource)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
}
