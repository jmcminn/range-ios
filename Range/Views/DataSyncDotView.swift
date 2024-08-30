import Combine
import Foundation
import UIKit

func _dataSyncInfoCard(_ state: UserDataSyncState.State) -> SheetCardViewController {
    let title = state == .offlinePending ? "Media Sync Pending" : "Media Sync In-progress"
    let description = state == .offlinePending
        ?
        "Your device currently has no Internet connection or uploading media via an internet connection has been disabled.\n\nYou can continue to use the app and when your device has an Internet connection or wifi access, all pending media will be synced to your Range Organization automatically when the app is open."
        :
        "Your device has established an Internet connection or wifi access and is currently syncing your pending media to your Organization. Once complete, this banner will disappear."
    return SheetCardViewController(icon: UIImage(systemName: "photo"), title: title, description: description)
}

class DataSyncDotView: UIView {
    private let state: UserDataSyncState
    private let bgView = UIView()
    private let dotView = UIView()
    private var subscriptions = Set<AnyCancellable>()
    var onTapped: (() -> Void)?
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: 40, height: 40)
    }

    init(_ state: UserDataSyncState) {
        self.state = state
        super.init(frame: .zero)
        
        bgView.layer.cornerRadius = 11
        bgView.layer.borderWidth = 1
        bgView.backgroundColor = .dynamic(.Neutral_09)
        addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.width.height.equalTo(22)
            make.center.equalToSuperview()
        }
        bgView.isUserInteractionEnabled = false

        dotView.layer.cornerRadius = 5
        addSubview(dotView)
        dotView.snp.makeConstraints { make in
            make.width.height.equalTo(10)
            make.center.equalToSuperview()
        }
        dotView.isUserInteractionEnabled = false
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.duration = 0.5
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.5
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.autoreverses = true
        scaleAnimation.isRemovedOnCompletion = false   //Set this property to false.
        dotView.layer.add(scaleAnimation, forKey: "scale")
        
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
            dotView.backgroundColor = .Orange_Banner
            isHidden = false
        case .onlineSync:
            dotView.backgroundColor = .Special_03
            isHidden = false
        case .noPending:
            isHidden = true
        }
    }
}
