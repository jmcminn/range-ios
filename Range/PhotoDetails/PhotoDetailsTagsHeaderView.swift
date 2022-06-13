import UIKit

/// Header view for tags.
/// Contains a search view and selected tags below.
/// The layout supports collapsing the search view.
class PhotoDetailsTagsHeaderView: UIView {
    var searchView: SearchView!
    var selectedTagsView: UIView!
    private var bottomStroke: UIView!

    /// shows/hides the bottom stroke (+ the shadow)
    var bottomStrokeVisible: Bool = false {
        didSet {
            updateBottomStroke()
        }
    }

    init() {
        super.init(frame: .zero)

        backgroundColor = .dynamicColor(light: .Neutral_01, dark: .Neutral_10)
        buildViews()

        updateBottomStroke()
    }

    /// Creates views, adds them to header and configure the layout
    private func buildViews() {
        buildTagsSearchView()
        buildSelectedTagsView()
        buildBottomStroke()

        addSubview(searchView)
        addSubview(selectedTagsView)
        addSubview(bottomStroke)

        searchView.snp.makeConstraints { make in
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
        bottomStroke.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// update colors that don't adapt automatically to appearance change
    func updateColors() {
        searchView?.updateColors()
        updateShadow()
    }

    private func buildTagsSearchView() {
        searchView = SearchView(placeholderText: String(localized: "Search for, or add a tag"))
    }

    private func buildSelectedTagsView() {
        selectedTagsView = UIView()
        selectedTagsView.layer.borderColor = UIColor.Primary_Blue_06.cgColor
        selectedTagsView.layer.borderWidth = 1
    }

    private func buildBottomStroke() {
        bottomStroke = UIView()
        bottomStroke.backgroundColor = .dynamicColor(light: .Neutral_04, dark: .Neutral_08)
    }

    /// update bottom stroke visibility (+ shadow)
    private func updateBottomStroke() {
        bottomStroke.isHidden = !bottomStrokeVisible
        updateShadow()
    }

    /// updates shadow color based on the interface style and visibility based on the `bottomStrokeVisible`
    private func updateShadow() {
        if bottomStrokeVisible {
            let darkMode = traitCollection.userInterfaceStyle == .dark
            if darkMode {
                setShadowWithFigmaValues(x: 0, y: 6, blur: 10, opacity: 0.1)
            } else {
                setShadowWithFigmaValues(x: 0, y: 3, blur: 6, opacity: 0.1)
            }
        } else {
            layer.shadowOpacity = 0
        }
    }
}
