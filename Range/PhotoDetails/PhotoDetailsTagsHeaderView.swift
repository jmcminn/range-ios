import UIKit

class PhotoDetailsTagsHeaderView: UIView {
    var tagsSearchView: SearchView!
    var selectedTagsView: UIView!

    init() {
        super.init(frame: .zero)

        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        buildViews()
    }

    /// Creates views, adds them to header and configure the layout
    private func buildViews() {
        buildTagsSearchView()
        buildSelectedTagsView()

        addSubview(tagsSearchView)
        addSubview(selectedTagsView)

        tagsSearchView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview()
            make.bottom.equalTo(selectedTagsView.snp.top).offset(-16)
                .priority(.high) // if the view is collapsed don't enforce this constraint
        }
        selectedTagsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(32)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// update colors that don't adapt automatically to appearance change
    func updateColors() {
        tagsSearchView?.updateColors()
    }

    private func buildTagsSearchView() {
        tagsSearchView = SearchView(placeholderText: String(localized: "Search for, or add a tag"))
    }

    private func buildSelectedTagsView() {
        selectedTagsView = UIView()
        selectedTagsView.layer.borderColor = UIColor.Primary_Blue_06.cgColor
        selectedTagsView.layer.borderWidth = 1
    }
}
