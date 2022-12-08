import Foundation
import UIKit

/// Card view controller presenting a list of canvases to choose from.
/// It presents the overlay over the presenting view controller.
/// It can be dismissed by tapping the overlay, dragging down or tappin on the close button.
class CanvasSelectorCardViewController: SheetCardViewController {
    let canvases: [PDFCanvas]
    private let selectedCanvas: PDFCanvas?
    private let tableView = UITableView(frame: .zero, style: .plain)

    var onCanvasSelected: ((PDFCanvas) -> Void)?

    /// Initializer
    ///
    /// - Parameters:
    ///     - title:                         title of the card
    ///     - canvases:               canvases to show in the selector
    init(
        title: String,
        canvases: [PDFCanvas],
        selectedCanvas: PDFCanvas?,
        onCanvasSelected: ((PDFCanvas) -> Void)? = nil
    ) {
        self.canvases = canvases
        self.selectedCanvas = selectedCanvas
        super.init(icon: UIImage(systemName: "square.3.layers.3d"), title: title)
        self.onCanvasSelected = onCanvasSelected
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
        tableView.register(CanvasTableViewCell.self, forCellReuseIdentifier: "CanvasCell")
    }

    override func traitCollectionDidChange(_: UITraitCollection?) {
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

extension CanvasSelectorCardViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        canvases.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CanvasCell", for: indexPath) as! CanvasTableViewCell
        let canvas = canvases[indexPath.row]
        cell.setCanvas(canvas, selected: canvas == selectedCanvas)
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // this should be considered a hack - there's no easy way of adding a border around the section in table view
        tableView.addBackgroundWithBorder(
            forCell: cell,
            forRowAt: indexPath,
            backgroundColor: .dynamicColor(light: .Neutral_02, dark: .Neutral_09),
            borderColor: .dynamicColor(light: .Neutral_04, dark: .Neutral_07),
            selectedBackgroundColor: .systemGray4 // this is what selectedBackgroundView uses by default
        )
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let canvas = canvases[indexPath.row]
        dismissCard()
        onCanvasSelected?(canvas)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func tableView(_: UITableView, heightForFooterInSection _: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
}
