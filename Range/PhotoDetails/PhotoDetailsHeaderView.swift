import UIKit

/// Header view with the photo and tags/description switch
class PhotoDetailsHeaderView: UIView {
    /// The photo
    private let image: UIImage

    var photoView: UIImageView!
    var tagsDescriptionSegmentedControl: SegmentedControl!
    var onTagsSelected: (() -> Void)?
    var onDescriptionSelected: (() -> Void)?

    init(image: UIImage) {
        self.image = image
        super.init(frame: .zero)

        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        buildViews()
    }

    /// Creates views, adds them to header and configure the layout
    private func buildViews() {
        buildPhotoView()
        buildTagsDescriptionSegmentedControl()

        addSubview(photoView)
        addSubview(tagsDescriptionSegmentedControl)

        photoView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview().priority(.high) // if the view is collapsed don't enforce this constraint
            make.height.greaterThanOrEqualTo(30)
            make.bottom.equalTo(tagsDescriptionSegmentedControl.snp.top).offset(-16)
        }
        tagsDescriptionSegmentedControl.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// update colors that don't adapt automatically to appearance change
    func updateColors() {
        photoView?.layer.borderColor = UIColor.dynamicColor(light: .Neutral_03, dark: .Neutral_08).cgColor
        tagsDescriptionSegmentedControl?.updateColors()
    }

    private func buildPhotoView() {
        photoView = UIImageView(image: image)
//        photoView.layer.cornerRadius = 13
//        photoView.layer.borderWidth = 1
        photoView.clipsToBounds = true
        photoView.contentMode = .scaleAspectFit
    }

    private func buildTagsDescriptionSegmentedControl() {
        tagsDescriptionSegmentedControl = SegmentedControl(items: [
            UIAction(
                title: String(localized: "Tags"),
                image: UIImage(systemName: "tag"),
                handler: { [weak self] _ in self?.onTagsSelected?() }
            ),
            UIAction(
                title: String(localized: "Description"),
                image: UIImage(systemName: "text.quote"),
                handler: { [weak self] _ in self?.onDescriptionSelected?() }
            ),
        ])
    }
}
