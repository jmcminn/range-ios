import Combine
import Foundation
import RealmSwift
import UIKit

class BillingErrorIndicatorView: UIView {
    private let organization: Organization
    private let bgView = UIView()
    private let imageView = UIImageView(image: UIImage(
        systemName: "exclamationmark.triangle",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 16)
    ))
    private var notificationToken: NotificationToken? = nil
    var onTapped: (() -> Void)?

    override var intrinsicContentSize: CGSize {
        CGSize(width: 40, height: 40)
    }

    init(_ organization: Organization) {
        self.organization = organization
        super.init(frame: .zero)
        
        addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.width.height.equalTo(30)
            make.center.equalToSuperview()
        }
        bgView.layer.cornerRadius = 15
        bgView.backgroundColor = UIColor(hexString: "FB7901")?.withAlphaComponent(0.2)
        bgView.isUserInteractionEnabled = false

        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        imageView.tintColor = .Orange_03
        imageView.isUserInteractionEnabled = false
        
        updateState()
        notificationToken = organization.observe { [weak self] change in
            self?.updateState()
        }
        
        isUserInteractionEnabled = true
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    
    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        notificationToken?.invalidate()
    }
    
    @objc private func tapped() {
        onTapped?()
    }
    
    func updateState() {
        guard !organization.isInvalidated else { return }
        // it's hidden if there's no error or if the organization is already blocked due to the error (then we show a fullscreen UI)
        isHidden = organization.billingErrorGracePeriodEnd == nil || organization.isBlockedDueToBillingError
    }
}
