//
//  PhotoSourceDialog.swift
//  Plekio
//
//  Created by Edward Gasparian on 25.09.2026.
//

import OSLog
import PhotosUI
import SwiftUI

// MARK: - View + photoSourceDialog

extension View {

    /// A dialog offering the camera (when there is one) and the photo library;
    /// `onPick` receives the chosen image. Cancelling anywhere calls nothing.
    func photoSourceDialog(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        onPick: @escaping (UIImage) -> Void
    ) -> some View {
        photoSourceDialog(title, isPresented: isPresented, onPick: onPick) { EmptyView() }
    }

    /// Same, with extra `actions` shown between the sources and Cancel.
    func photoSourceDialog<Actions: View>(
        _ title: LocalizedStringKey,
        isPresented: Binding<Bool>,
        onPick: @escaping (UIImage) -> Void,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        modifier(PhotoSourceDialog(title: title, isPresented: isPresented, onPick: onPick, actions: actions()))
    }
}

// MARK: - PhotoSourceDialog

private struct PhotoSourceDialog<Actions: View>: ViewModifier {

    // MARK: - Properties

    let title: LocalizedStringKey
    @Binding var isPresented: Bool
    let onPick: (UIImage) -> Void
    let actions: Actions

    @State private var showingLibrary = false
    @State private var showingCamera = false
    @State private var libraryItem: PhotosPickerItem?

    // MARK: - Body

    func body(content: Content) -> some View {
        content
            .confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
                // Hidden when there is no camera (simulator, some iPads).
                if CameraPicker.isAvailable {
                    Button("Take Photo (Camera)") { showingCamera = true }
                }
                Button("Choose from Library") { showingLibrary = true }
                actions
                Button("Cancel", role: .cancel) {}
            }
            .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    showingCamera = false
                    if let image { onPick(image) }
                }
                .ignoresSafeArea()
            }
            .onChange(of: libraryItem) { _, item in
                guard let item else { return }
                // Reset so picking the same photo again still triggers onChange.
                libraryItem = nil
                Task { await load(item) }
            }
    }

    // MARK: - Private

    private func load(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                AppLog.media.error("Picked photo had no data")
                return
            }
            // Decoding a full-size HEIC is not free; keep it off the main actor.
            let image = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
            guard let image else {
                AppLog.media.error("Picked photo could not be decoded")
                return
            }
            onPick(image)
        } catch {
            AppLog.media.error("Photo could not be loaded from the library: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - CameraPicker

/// The system camera. `onFinish` gets the photo, or nil when the user cancels.
struct CameraPicker: UIViewControllerRepresentable {

    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) {
            self.onFinish = onFinish
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}
