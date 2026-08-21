//
//  MediaPickerService.swift
//  PillFlow
//
//  Created by Edward Gasparian on 20.05.2026.
//

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
    
    private var continuation: CheckedContinuation<UIImage, Error>?
    
    func pickImage(source: MediaSource) async throws -> UIImage {
        // Защита от двойного вызова
        if continuation != nil {
            throw MediaPickerError.unknown
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            DispatchQueue.main.async {
                self.presentPicker(for: source)
            }
        }
    }
    
    private func presentPicker(for source: MediaSource) {
        guard let topVC = UIApplication.topViewController() else {
            finish(with: .failure(MediaPickerError.unknown))
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
    
    private func finish(with result: Result<UIImage, Error>) {
        continuation?.resume(with: result)
        continuation = nil
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
            if let image = object as? UIImage {
                self?.finish(with: .success(image))
            } else {
                self?.finish(with: .failure(MediaPickerError.unknown))
            }
        }
    }
}

// Утилита для поиска текущего экрана
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
