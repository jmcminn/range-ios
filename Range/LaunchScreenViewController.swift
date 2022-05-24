import SnapKit
import UIKit

/// View controller with the same layout as the launch screen to prolong showing the launch screen when loading the data.
class LaunchScreenViewController: UIViewController {
    override func viewDidLoad() {
        view.backgroundColor = .systemBackground

        let logoView = UIImageView(image: UIImage(named: "logo_side_by_side"))
        view.addSubview(logoView)
        logoView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(139)
            make.height.equalTo(40)
        }

        let topGlow = UIImageView(image: UIImage(named: "topglow"))
        view.addSubview(topGlow)
        topGlow.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }

        let bottomGlow = UIImageView(image: UIImage(named: "bottomglow"))
        view.addSubview(bottomGlow)
        bottomGlow.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}
