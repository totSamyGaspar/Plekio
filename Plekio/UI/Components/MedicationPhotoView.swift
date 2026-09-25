//
//  MedicationPhotoView.swift
//  Plekio
//
//  Created by Edward Gasparian on 28.08.2026.
//

import SwiftUI

struct MedicationPhotoView<Placeholder: View>: View {

    // MARK: - Properties

    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.databaseChanges) private var databaseChanges
    let medicationId: UUID
    let size: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    // MARK: - Body

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .task(id: medicationId) { await load() }
        // Edits keep the same id, so .task won't rerun; reload on course changes only
        // (not every write, or each logged dose would re-decode every photo).
        .onReceive(databaseChanges.publisher(for: [.courses])) { _ in
            Task { await load(force: true) }
        }
    }

    // MARK: - Private

    private func load(force: Bool = false) async {
        guard force || uiImage == nil else { return }
        uiImage = await imageLoader.image(for: medicationId, targetPointSize: size)
    }
}
