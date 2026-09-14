//
//  MediaPickerService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

import OSLog
import UIKit
import PhotosUI

enum MediaSource {
    case camera
    case photoLibrary
}

enum MediaPickerError: Error {
    case cancelled
    case unavailable
    case unknown
}

final class MediaPickerService: NSObject, MediaPickerServiceProtocol {

    /// The pick currently in flight. One slot — only one picker can be on screen.
    ///
    /// This is an app-wide singleton (see DIContainer), which made the old
    /// "if continuation != nil { throw }" guard a one-way door: any pick that never
    /// came back — `present` refused because something was already on top, or
    /// PHPicker's load callback never fired — left the slot occupied forever, and
    /// every later call in the whole app threw `.unknown` on the spot. The photo
    /// button then did nothing at all, silently, until the app was relaunched, and
    /// a medication saved in that state kept its placeholder. A new request now
    /// cancels the stale one instead of refusing.
    private var continuation: CheckedContinuation<UIImage, Error>?

    /// Identifies the current request, so a retry left over from a superseded pick
    /// can't present its picker over the new one or resume the wrong continuation.
    private var requestID = 0

    func pickImage(source: MediaSource) async throws -> UIImage {
        // Whatever was in flight can no longer deliver: its picker is gone.
        finish(with: .failure(MediaPickerError.cancelled))
        requestID &+= 1
        let id = requestID

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            DispatchQueue.main.async {
                self.presentPicker(for: source, requestID: id)
            }
        }
    }

    /// How long to keep waiting for whatever is on screen to get out of the way,
    /// in 0.1s steps. The photo source is chosen in a confirmationDialog, and
    /// SwiftUI runs the button's action while UIKit is still dismissing that
    /// alert — the moment `present` is called the alert is often still the
    /// presented controller.
    private static let presentationRetryLimit = 8

    private func presentPicker(for source: MediaSource, requestID id: Int, attempt: Int = 0) {
        guard id == requestID else { return }

        guard let topVC = UIApplication.topViewController() else {
            AppLog.media.error("Photo picker could not be presented: no top view controller")
            finish(with: .failure(MediaPickerError.unknown))
            return
        }

        // Presenting on a controller that is already presenting is a no-op UIKit
        // only logs about: no delegate call ever arrives, so the pick hangs and
        // takes the continuation slot with it — which the user sees as the photo
        // button doing nothing at all. Wait for the dismissal instead.
        if topVC.presentedViewController != nil {
            guard attempt < Self.presentationRetryLimit else {
                AppLog.media.error("Photo picker could not be presented: another screen is still on top")
                finish(with: .failure(MediaPickerError.unavailable))
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.presentPicker(for: source, requestID: id, attempt: attempt + 1)
            }
            return
        }

        if source == .camera {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                finish(with: .failure(MediaPickerError.unavailable))
                return
            }
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            topVC.present(picker, animated: true)

        } else {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.filter = .images
            config.selectionLimit = 1

            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            topVC.present(picker, animated: true)
        }
    }

    /// Resumes the pending pick, if there is one, exactly once.
    ///
    /// The slot is cleared before `resume` rather than after: resuming can run the
    /// awaiting code synchronously, and that code is allowed to start the next pick.
    private func finish(with result: Result<UIImage, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

// MARK: - Delegates (UIImagePickerController & PHPickerViewController)

extension MediaPickerService: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [weak self] in
            if let image = info[.originalImage] as? UIImage {
                self?.finish(with: .success(image))
            } else {
                self?.finish(with: .failure(MediaPickerError.unknown))
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.finish(with: .failure(MediaPickerError.cancelled))
        }
    }
}

extension MediaPickerService: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard let result = results.first else {
            finish(with: .failure(MediaPickerError.cancelled))
            return
        }
        
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            // This callback arrives on a private queue, and `continuation` is only
            // ever touched on the main thread: resumed straight from here it races
            // the next pickImage call.
            DispatchQueue.main.async {
                if let image = object as? UIImage {
                    self?.finish(with: .success(image))
                } else {
                    AppLog.media.error("Photo could not be loaded from the library: \(error?.localizedDescription ?? "unknown reason", privacy: .public)")
                    self?.finish(with: .failure(MediaPickerError.unknown))
                }
            }
        }
    }
}

extension UIApplication {
    static func topViewController(base: UIViewController? = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?.rootViewController) -> UIViewController? {
            
            if let nav = base as? UINavigationController {
                return topViewController(base: nav.visibleViewController)
            }
            if let tab = base as? UITabBarController {
                if let selected = tab.selectedViewController {
                    return topViewController(base: selected)
                }
            }
            if let presented = base?.presentedViewController {
                return topViewController(base: presented)
            }
            return base
        }
}
