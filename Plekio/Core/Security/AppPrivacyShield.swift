import SwiftUI
import UIKit

/// A separate window covers presented sheets as well as the root during app snapshots.
struct AppPrivacyShield: UIViewRepresentable {
    let isEnabled: Bool

    func makeUIView(context: Context) -> ShieldAnchor { ShieldAnchor() }
    func updateUIView(_ view: ShieldAnchor, context: Context) { view.isEnabled = isEnabled }

    final class ShieldAnchor: UIView {
        var isEnabled = false
        private var shield: UIWindow?

        override init(frame: CGRect) {
            super.init(frame: frame)
            NotificationCenter.default.addObserver(self, selector: #selector(hideContent),
                name: UIApplication.willResignActiveNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(showContent),
                name: UIApplication.didBecomeActiveNotification, object: nil)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        @objc private func hideContent() {
            guard isEnabled, shield == nil, let scene = window?.windowScene else { return }
            let cover = UIWindow(windowScene: scene)
            cover.windowLevel = .alert + 1
            let controller = UIViewController()
            controller.view.backgroundColor = .systemBackground
            let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
            icon.tintColor = .secondaryLabel
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false
            controller.view.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: controller.view.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: 40),
                icon.heightAnchor.constraint(equalToConstant: 40)
            ])
            cover.rootViewController = controller
            cover.isHidden = false
            shield = cover
        }

        @objc private func showContent() {
            shield?.isHidden = true
            shield = nil
        }
    }
}
