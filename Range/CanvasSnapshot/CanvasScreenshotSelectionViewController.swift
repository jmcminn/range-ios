import Foundation
import UIKit

enum CanvasSnapshotSelectionShape {
    case portrait // 4 x 3 (width x height proportions)
    case square // 1 x 1
    case landscape // 3 x 4
}

/// Showing the overlay and buttons for canvas snapshot selection.
/// We cannot use SwiftUI here because this needs to be a passthrough view and it's not supported to have user interaction passthrough
/// views implemented using swiftUI and added to UIView using UIHostingController...
class CanvasSnapshotSelectionViewController: UIViewController {
    private let canvasViewController: CanvasViewController
    var selectionShape: CanvasSnapshotSelectionShape = .landscape
    private let backgroundView = SelectionBackgroundView()
    private let selectionBorderView = UIView()
    private let titleView = UIStackView()
    private let panAndZoomIndicatorView = ToastView(
        iconName: "hand.point.up.left",
        text: "Pan and zoom to get your desired viewport.",
        backgroundColor: .Neutral_10, blurBackground: false
    )
    private var cancelButton: RangeButton!
    private let shapeButtonsView = UIView()
    private var shapeButtons: [CanvasSnapshotSelectionShape: RangeButton] = [:]
    private var doneButton: RangeButton!
    var onCancel: (() -> Void)?
    /// Called when user selected the snapshot area and confirmed. The first parameter is the snapshot area frame
    /// in the canvasViewController coordinates
    var onDone: ((CGRect) -> Void)?

    /// id of registered delegate
    private var canvasDelegateId: UUID?

    init(canvasViewController: CanvasViewController) {
        self.canvasViewController = canvasViewController
        super.init(nibName: nil, bundle: nil)
    }

    override func loadView() {
        view = PassthroughView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

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

        setupTitleView()
        view.addSubview(titleView)
        titleView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(12)
        }

        setupButtons()
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

        setupShapeButtons()
        view.addSubview(shapeButtonsView)
        shapeButtonsView.snp.makeConstraints { make in
            make.centerY.equalTo(doneButton)
            make.centerX.equalToSuperview()
            make.width.equalTo(155)
            make.height.equalTo(48)
        }

        view.addSubview(panAndZoomIndicatorView)
        panAndZoomIndicatorView.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(doneButton.snp.top).offset(-16)
        }

        canvasDelegateId = canvasViewController.addDelegate(self)
        setSelectionShape(.landscape)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let selectionFrameWidth = view.bounds.width
        let selectionFrameHeight: CGFloat
        switch selectionShape {
        case .portrait: selectionFrameHeight = selectionFrameWidth * 4.0 / 3.0
        case .square: selectionFrameHeight = selectionFrameWidth
        case .landscape: selectionFrameHeight = selectionFrameWidth * 0.75
        }
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
                guard let self else { return }
                self.onDone?(self.selectionBorderView.frame)
            }
        ).withCustomRangeHighlightColor()
    }

    private func setupShapeButtons() {
        shapeButtonsView.layer.cornerRadius = 24
        // always a dark color, but select from the proper theme (light or dark)
        shapeButtonsView.backgroundColor = .Neutral_09

        let buttonConfig = UIButton.Configuration.iconButton(
            backgroundColor: .clear, foregroundColor: .Neutral_01,
            strokeColor: .clear, imagePointSize: 11, imageFontWeight: .bold
        )

        let buttonsImages: [CanvasSnapshotSelectionShape: String] = [
            .portrait: "rectangle.portrait.slash",
            .square: "square.slash",
            .landscape: "rectangle.slash",
        ]
        for (shape, imageName) in buttonsImages {
            let button = RangeButton(
                configuration: buttonConfig,
                primaryAction: UIAction(image: UIImage(systemName: imageName)) { [weak self] _ in
                    self?.setSelectionShape(shape)
                }
            )
            .withCustomRangeHighlightColor()
            .withSelectionConfig(backgroundColor: .Neutral_10, foregroundColor: .Pink_03, strokeColor: .Pink_03)

            shapeButtonsView.addSubview(button)
            shapeButtons[shape] = button
        }

        shapeButtons[.portrait]?.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.width.height.equalTo(48)
        }
        shapeButtons[.square]?.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(48)
        }
        shapeButtons[.landscape]?.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview()
            make.width.height.equalTo(48)
        }
    }

    private func setSelectionShape(_ shape: CanvasSnapshotSelectionShape) {
        selectionShape = shape
        for (key, button) in shapeButtons {
            button.isSelected = key == shape
        }
        view.setNeedsLayout()
        UIView.animate(withDuration: 0.1) {
            self.view.layoutIfNeeded()
        }
    }

    private func setupTitleView() {
        titleView.axis = .horizontal
        titleView.distribution = .equalSpacing
        titleView.spacing = 8
        titleView.alignment = .trailing

        let font = UIFont._preferredFont(forTextStyle: .body, symbolicTraits: .traitBold)
        let color = UIColor.Neutral_04
        let imageView = UIImageView(image: UIImage(
            systemName: "scissors",
            withConfiguration: UIImage.SymbolConfiguration(font: font)
        ))
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.tintColor = color
        titleView.addArrangedSubview(imageView)

        let titleLabel = UILabel()
        titleLabel.text = "Add Snippet"
        titleLabel.textColor = color
        titleLabel.font = font
        titleLabel.adjustsFontForContentSizeCategory = true
        titleView.addArrangedSubview(titleLabel)
    }

    private func hidePanAndZoomIndicatorView() {
        UIView.animate(withDuration: 0.2,
                       animations: {
                           self.panAndZoomIndicatorView.alpha = 0
                       }, completion: { _ in
                           self.panAndZoomIndicatorView.removeFromSuperview()
                       })
    }
}

/// CanvasViewControllerDelegate
extension CanvasSnapshotSelectionViewController: CanvasViewControllerDelegate {
    func canvasCameraChanged(reason: CanvasCameraChangeReason) {
        if reason == .pan || reason == .zoom {
            hidePanAndZoomIndicatorView()
        }
    }

    func canvasTapRecognized(at _: CGPoint) {}
    func canvasLongPressRecognized(at _: CGPoint) {}
}

class SelectionBackgroundView: UIVisualEffectView {
    var selectionFrame: CGRect = .zero { didSet {
        updateSelectionFrame()
    }}

    init() {
        super.init(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

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
