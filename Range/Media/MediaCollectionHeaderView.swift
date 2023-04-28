import Foundation
import UIKit

class MediaCollectionViewHeader: UICollectionReusableView {
    static let horizontalInset = 16.0

    let label = UILabel()
    private var selectedView: UIView?
    private var unselectedView: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.textColor = .dynamic(.Neutral_05)
        label.numberOfLines = 0
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(MediaCollectionViewHeader.horizontalInset)
            make.bottom.equalToSuperview()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        label.text = nil
        mark(selected: nil)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    /// selected is optional, if nil then header is not selectable
    func mark(selected: Bool?) {
        if let selected = selected {
            let leadingView: UIView
            if selected {
                setupSelectedView()
                leadingView = selectedView!
            } else {
                setupUnselectedView()
                leadingView = unselectedView!
            }
            selectedView?.isHidden = !selected
            unselectedView?.isHidden = selected
            label.snp.remakeConstraints { make in
                make.leading.equalTo(leadingView.snp.trailing).offset(8)
                make.trailing.equalToSuperview().inset(MediaCollectionViewHeader.horizontalInset)
                make.bottom.equalToSuperview()
            }
        } else {
            label.snp.remakeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(MediaCollectionViewHeader.horizontalInset)
                make.bottom.equalToSuperview()
            }
            selectedView?.isHidden = true
            unselectedView?.isHidden = true
        }
    }

    private func setupSelectedView() {
        guard selectedView == nil else { return }

        let selectedView = ImageMediaCollectionViewCell.createdSelectedCheckmark()
        selectedView.layer.borderWidth = 0
        selectedView.layer.cornerRadius = 10
        addSubview(selectedView)
        selectedView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalTo(label)
            make.width.height.equalTo(20)
        }
        layoutIfNeeded()
        self.selectedView = selectedView
    }

    private func setupUnselectedView() {
        guard unselectedView == nil else { return }

        let unselectedView = UIView()
        unselectedView.layer.cornerRadius = 10
        unselectedView.backgroundColor = .dynamic(.Neutral_09)
        unselectedView.layer.borderWidth = 1
        unselectedView.layer.borderColor = UIColor.Neutral_06.cgColor
        addSubview(unselectedView)
        unselectedView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.centerY.equalTo(label)
            make.width.height.equalTo(20)
        }
        self.unselectedView = unselectedView
    }

    private func updateColors() {
        unselectedView?.layer.borderColor = UIColor.Neutral_06.cgColor
    }
}
