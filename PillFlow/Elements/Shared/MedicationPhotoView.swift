//
//  MedicationPhotoView.swift
//  PillFlow
//
//  Medication photo, loaded lazily from ImageCache.
//
//  Folds the "@State uiImage + onAppear + reload when the database changes"
//  pairing into one place, the way DiaryAsyncPhoto does for the diary.
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
        // signal instead. Courses only, not every write: otherwise each dose logged
        // on the dashboard sends every visible photo back to disk to be read and
        // decoded again.
        .onReceive(NotificationCenter.default.publisher(forDatabaseChanges: [.courses])) { _ in
            Task { await load(force: true) }
        }
    }
    
    private func load(force: Bool = false) async {
        guard force || uiImage == nil else { return }
        uiImage = await ImageCache.shared.image(for: medicationId, targetPointSize: size)
    }
}
