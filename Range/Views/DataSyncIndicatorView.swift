import Combine
import Foundation
import UIKit

func _dataSyncInfoCard(_ state: UserDataSyncState.State) -> SheetCardViewController {
    let title = state == .offlinePending ? "Data Sync Pending" : "Data Sync In-progress"
    let description = state == .offlinePending
        ? "Your device has no Internet connection or you have disabled “uploading data via cellular data” in the Range app settings.\n\nYou can continue to use the Range app and we’ll sync all your data once you have an Internet connection."
        : "We are currently syncing your offline data to Range. Please keep the app open and once the syncing is complete, this banner will disappear."
    let iconBgView = DataSyncIconBackgroundView()
    iconBgView.snp.makeConstraints { make in
        make.width.height.equalTo(30)
    }
    return SheetCardViewController(
        icon: UIImage(systemName: "arrow.triangle.2.circlepath"),
        iconTintColor: state == .offlinePending ? .Orange_Banner : .Special_03,
        iconImageConfig: UIImage.SymbolConfiguration(pointSize: 16, weight: .black),
        iconBgView: iconBgView,
        title: title, description: description)
}

class DataSyncIndicatorView: UIView {
    private let state: UserDataSyncState
    private let bgView = DataSyncIconBackgroundView()
    private let imageView = UIImageView(image: UIImage(
        systemName: "arrow.triangle.2.circlepath",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .black)
    ))
    private var subscriptions = Set<AnyCancellable>()
    var onTapped: (() -> Void)?
    var onHiddenChange: (() -> Void)?

    override var intrinsicContentSize: CGSize {
        CGSize(width: 40, height: 40)
    }

    init(_ state: UserDataSyncState) {
        self.state = state
        super.init(frame: .zero)
        
        addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.width.height.equalTo(30)
            make.center.equalToSuperview()
        }
        bgView.isUserInteractionEnabled = false

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        imageView.isUserInteractionEnabled = false
        
        let fadeAnimation = CABasicAnimation(keyPath: "opacity")
        fadeAnimation.duration = 1.5
        fadeAnimation.fromValue = 1.0
        fadeAnimation.toValue = 0.3
        fadeAnimation.repeatCount = .infinity
        fadeAnimation.autoreverses = true
        fadeAnimation.isRemovedOnCompletion = false   //Set this property to false.
        layer.add(fadeAnimation, forKey: "opacity")
        
        updateState()
        
        state.$state
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in self?.updateState() }
            .store(in: &subscriptions)
        
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func tapped() {
        onTapped?()
    }
    
    func updateState() {
        switch state.state {
        case .offlinePending:
            imageView.tintColor = .Orange_Banner
            isHidden = false
            onHiddenChange?()
        case .onlineSync:
            imageView.tintColor = .Special_03
            isHidden = false
            onHiddenChange?()
        case .noPending:
            isHidden = true
            onHiddenChange?()
        }
    }
}

class DataSyncIconBackgroundView: UIView {
    init() {
        super.init(frame: .zero)
        
        layer.borderWidth = 1
        backgroundColor = .dynamic(.Neutral_09)
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// update colors
    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    private func updateColors() {
        layer.borderColor = chooseColor(.Neutral_07).cgColor
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = frame.width / 2.0
    }
}
