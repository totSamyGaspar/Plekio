//
//  ProfileAvatar.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.09.2026.
//

import SwiftUI

/// The round profile picture, or a placeholder when there is none.
/// Loads through `DiaryAsyncPhoto`, the app's shared cached-photo view.
struct ProfileAvatar: View {

    // MARK: - Properties

    let id: UUID?
    let side: CGFloat

    // MARK: - Body

    var body: some View {
        Group {
            if let id {
                DiaryAsyncPhoto(photoId: id, targetPointSize: side)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.textSecondary.opacity(0.35))
            }
        }
        .frame(width: side, height: side)
        .clipShape(.circle)
    }
}
