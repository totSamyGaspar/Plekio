//
//  MedicationPhotoView.swift
//  PillFlow
//
//  Medication photo, loaded lazily from ImageCache.
//
//  The same "@State uiImage + onAppear + reload on .databaseDidUpdate"
//  pairing was duplicated in MedicationCardView and MedicationRowView. The
//  diary already folds that logic into DiaryAsyncPhoto; this is the same for
//  medications.
//

import SwiftUI

struct MedicationPhotoView<Placeholder: View>: View {
    let medicationId: UUID
    let size: CGFloat
    let cornerRadius: CGFloat
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

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
        // The medication id does not change on an edit (it is the same SwiftData
        // object), so .task never fires a second time — reload on the database
        // signal instead.
        .onReceive(NotificationCenter.default.publisher(for: .databaseDidUpdate)) { _ in
            Task { await load(force: true) }
        }
    }

    private func load(force: Bool = false) async {
        guard force || uiImage == nil else { return }
        uiImage = await ImageCache.shared.image(for: medicationId)
    }
}
