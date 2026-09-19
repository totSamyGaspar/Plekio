//
//  ProfileAvatar.swift
//  PillFlow
//

import SwiftUI

/// The profile picture, round, or a placeholder when there is none.
///
/// Loading goes through `DiaryAsyncPhoto`: it is named for where it was first
/// needed, but it is the app's one "read a photo id from the cache at the size
/// it is drawn" view, and a fourth copy of that logic is what it exists to
/// prevent.
struct ProfileAvatar: View {

    let id: UUID?
    let side: CGFloat

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
