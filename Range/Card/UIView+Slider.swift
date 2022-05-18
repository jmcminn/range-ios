import UIKit

extension UIView {
    /// Adds slider view to this view and returns it for reference
    @discardableResult func installSliderView() -> UIView {
        let sliderView = UIView()
        sliderView.backgroundColor = .dynamicColor(light: .Neutral_05, dark: .Neutral_06)
        sliderView.layer.cornerRadius = 2.5
        addSubview(sliderView)
        sliderView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(33)
            make.height.equalTo(5)
            make.top.equalTo(8)
        }
        return sliderView
    }
}
