import Foundation
import UIKit

enum CanvasScreenshotSelectionShape {
    case horizontal // 4 x 3 (width x height proportions)
    case square // 1 x 1
    case vertical // 3 x 4
}

/// Showing the overlay and buttons for canvas screenshot selection.
/// We cannot use SwiftUI here because this needs to be a passthrough view and it's not supported to have user interaction passthrough
/// views implemented using swiftUI and added to UIView using UIHostingController...
class CanvasScreenshotSelectionViewController: UIViewController {
    var selectionShape: CanvasScreenshotSelectionShape = .horizontal
    private let backgroundView = SelectionBackgroundView()
    private let selectionBorderView = UIView()
    private var cancelButton: RangeButton!
    private var doneButton: RangeButton!
    var onCancel: (() -> Void)?
    var onDone: (() -> Void)?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = PassthroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupButtons()

        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(selectionBorderView)
        selectionBorderView.backgroundColor = .clear
        selectionBorderView.isUserInteractionEnabled = false
        selectionBorderView.layer.borderWidth = 2
        selectionBorderView.layer.borderColor = UIColor.Pink_03.cgColor
        selectionBorderView.layer.cornerRadius = 8

        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(28)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom).offset(-12)
            make.width.height.equalTo(48)
        }
        view.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(28)
            make.width.height.bottom.equalTo(cancelButton)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // TODO: 2560
        // hardcoded for .horizontal with no bounds check
        let selectionFrameWidth = view.bounds.width
        let selectionFrameHeight = selectionFrameWidth * 0.75
        let selectionFrame = CGRect(
            x: 0, y: view.bounds.midY - selectionFrameHeight / 2, width: selectionFrameWidth,
            height: selectionFrameHeight
        )

        backgroundView.selectionFrame = selectionFrame
        selectionBorderView.frame = selectionFrame
    }

    private func setupButtons() {
        cancelButton = RangeButton(
            configuration: UIButton.Configuration.iconButton(
                backgroundColor: .Red_03, foregroundColor: .Neutral_01,
                strokeColor: .Red_04, imagePointSize: 14
            ),
            primaryAction: UIAction(image: UIImage(systemName: "xmark")) { [weak self] _ in
                self?.onCancel?()
            }
        ).withCustomRangeHighlightColor()

        doneButton = RangeButton(
            configuration: UIButton.Configuration.iconButton(
                backgroundColor: .Green_03, foregroundColor: .Neutral_01,
                strokeColor: .Green_04, imagePointSize: 14
            ),
            primaryAction: UIAction(image: UIImage(systemName: "checkmark")) { [weak self] _ in
                self?.onDone?()
            }
        ).withCustomRangeHighlightColor()
    }
}

class SelectionBackgroundView: UIVisualEffectView {
    var selectionFrame: CGRect = .zero { didSet {
        updateSelectionFrame()
    }}

    init() {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterial))

        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }

    private func updateSelectionFrame() {
        let mask = CAShapeLayer()
        let path = CGMutablePath()
        // add the bounds and then rectangle + set the fillRule to evenOdd to invert the mask
        path.addRect(bounds)
        path.addPath(UIBezierPath(roundedRect: selectionFrame, cornerRadius: 8).cgPath)
        mask.path = path
        mask.fillRule = .evenOdd
        layer.mask = mask
    }
}
