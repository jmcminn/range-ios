import Foundation
import UIKit

class AdditionalInformationCardViewController: SheetCardViewController {
    private let collaboration: Collaboration
    private let backgroundView = UIView()

    init(collaboration: Collaboration) {
        self.collaboration = collaboration
        super.init(
            icon: UIImage(systemName: "globe"),
            title: String(localized: "Additional Information")
        )
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        backgroundView.backgroundColor = .dynamic(.Neutral_09)
        backgroundView.layer.borderWidth = 1
        backgroundView.layer.cornerRadius = 16
        backgroundView.clipsToBounds = true
        containerView.addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(sheetHeaderView.snp.bottom)
        }

        let verticalStack = UIStackView()
        verticalStack.axis = .vertical
        verticalStack.spacing = 6

        let coordinatesFormatter = NumberFormatter()
        coordinatesFormatter.numberStyle = .decimal
        coordinatesFormatter.maximumFractionDigits = 8

        var copyAllString = ""

        if case let .point(point) = collaboration.geometry.first?.geometry,
           let latString = coordinatesFormatter.string(from: point.coordinates.latitude as NSNumber),
           let lngString = coordinatesFormatter.string(from: point.coordinates.longitude as NSNumber)
        {
            verticalStack.addArrangedSubview(rowView(label: "Latitude:", value: latString))
            verticalStack.addArrangedSubview(rowView(label: "Longitude:", value: lngString))

            copyAllString.append("Latitude: \(latString), Longitude: \(lngString)")
        }

        if let elevationMeters = collaboration.geometry.first?.elevation {
            let meters = Measurement(value: elevationMeters, unit: UnitLength.meters)
            let feet = meters.converted(to: UnitLength.feet)
            let elevationFormatter = MeasurementFormatter()
            elevationFormatter.unitOptions = .providedUnit
            elevationFormatter.unitStyle = .medium
            elevationFormatter.numberFormatter.maximumFractionDigits = 2
            let metersString = elevationFormatter.string(from: meters)
            let feetString = elevationFormatter.string(from: feet)
            verticalStack.addArrangedSubview(rowView(label: "Elevation:", value: metersString))
            verticalStack.addArrangedSubview(rowView(label: "", value: feetString))

            copyAllString.append(", Elevation: \(metersString) / \(feetString)")
        }

        backgroundView.addSubview(verticalStack)
        verticalStack.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview().inset(16)
        }

        let copyButton = RangeButton(
            configuration: UIButton.Configuration.blueButton(
                imageTextStyle: .subheadline,
                imagePlacement: .leading,
                cornerRadius: 0
            ),
            primaryAction: UIAction(title: "Copy to Clipboard", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.string = copyAllString
            }
        ).withCustomRangeHighlightColor()
        backgroundView.addSubview(copyButton)
        copyButton.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(verticalStack.snp.bottom).offset(16)
        }
    }

    private func rowView(label labelString: String, value valueString: String) -> UIView {
        let row = UIView()
        let label = labelView(labelString)
        let value = valueView(valueString)
        let image = imageView()

        row.addSubview(label)
        row.addSubview(value)
        row.addSubview(image)

        label.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.height.lessThanOrEqualToSuperview()
        }
        value.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(image.snp.leading).offset(-2)
            make.height.lessThanOrEqualToSuperview()
        }
        image.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.height.lessThanOrEqualToSuperview()
        }
        row.addGestureRecognizer(BindableGestureRecognizer(action: {
            UIPasteboard.general.string = valueString
        }))
        return row
    }

    private func labelView(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .dynamic(.Neutral_05)
        label.font = .preferredFont(forTextStyle: .subheadline)
        return label
    }

    private func valueView(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textAlignment = .right
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .dynamic(.Neutral_04)
        label.font = .preferredFont(forTextStyle: .subheadline)
        return label
    }

    private func imageView() -> UIView {
        guard let image = UIImage(systemName: "doc.on.doc") else { return UIView() }

        let configuredImage = image
            .withConfiguration(UIImage.SymbolConfiguration(font: .preferredFont(forTextStyle: .caption1)))
        let imageView = UIImageView(image: configuredImage)
        imageView.tintColor = .dynamic(.Neutral_04)
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .vertical)
        return imageView
    }

    override func updateColors() {
        super.updateColors()
        backgroundView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    override func height(forContainer cardContainerView: UIView, cardPosition: CardPosition) -> CGFloat {
        let baseHeight = super.height(forContainer: cardContainerView, cardPosition: cardPosition)

        if cardPosition == .max {
            view.layoutIfNeeded()
            return baseHeight + backgroundView.frame.height + 12
        }
        return baseHeight
    }
}
