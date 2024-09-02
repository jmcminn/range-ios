import Combine
import Foundation
import UIKit

func _dataSyncInfoCard(_ state: UserDataSyncState.State) -> SheetCardViewController {
    let title = state == .offlinePending ? "Data Sync Pending" : "Data Sync In-progress"
    let description = state == .offlinePending
        ?
        "Your device currently has no Internet connection or uploading media via an internet connection has been disabled.\n\nYou can continue to use the app and when your device has an Internet connection or wifi access, all pending media will be synced to your Range Organization automatically when the app is open."
        :
        "Your device has established an Internet connection or wifi access and is currently syncing your pending media to your Organization. Once complete, this banner will disappear."
    return SheetCardViewController(
        icon: UIImage(systemName: "arrow.triangle.2.circlepath.circle.fill"),
        iconTintColor: state == .offlinePending ? .Orange_Banner : .Special_03,
        title: title, description: description)
}

class DataSyncIndicatorView: UIView {
    private let state: UserDataSyncState
    private let bgView = UIView()
    private let imageView = UIImageView(image: UIImage(systemName: "arrow.triangle.2.circlepath.circle.fill"))
    private var subscriptions = Set<AnyCancellable>()
    var onTapped: (() -> Void)?
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: 40, height: 40)
    }

    init(_ state: UserDataSyncState) {
        self.state = state
        super.init(frame: .zero)
        
        bgView.layer.cornerRadius = 12
        bgView.layer.borderWidth = 1
        bgView.backgroundColor = .dynamic(.Neutral_09)
        addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
            make.center.equalToSuperview()
        }
        bgView.isUserInteractionEnabled = false

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        imageView.isUserInteractionEnabled = false
        
        let scaleAnimation = CABasicAnimation(keyPath: "opacity")
        scaleAnimation.duration = 1.0
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 0.5
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.autoreverses = true
        scaleAnimation.isRemovedOnCompletion = false   //Set this property to false.
        imageView.layer.add(scaleAnimation, forKey: "opacity")
        
        updateColors()
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
    
    /// update colors
    override func traitCollectionDidChange(_: UITraitCollection?) {
        updateColors()
    }

    private func updateColors() {
        bgView.layer.borderColor = chooseColor(.Neutral_07).cgColor
    }

    func updateState() {
        switch state.state {
        case .offlinePending:
            imageView.tintColor = .Orange_Banner
            isHidden = false
        case .onlineSync:
            imageView.tintColor = .Special_03
            isHidden = false
        case .noPending:
            isHidden = true
        }
    }
}
