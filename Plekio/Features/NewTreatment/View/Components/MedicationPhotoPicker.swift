//
//  MedicationPhotoPicker.swift
//  Plekio
//
//  Created by Edward Gasparian on 19.11.2026.
//

import SwiftUI

/// The medication form's photo row: a round preview, then Add/Change and Delete.
struct MedicationPhotoPicker: View {

    let image: UIImage?
    let onChoose: () -> Void
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onChoose) {
                PhotoPreview(image: image)
            }

            HStack(spacing: 20) {
                Button(action: onChoose) {
                    Text(image == nil ? "Add" : "Change")
                        .foregroundStyle(Color.accentPrimary)
                }

                if image != nil {
                    Button("Delete", role: .destructive) {
                        withMotion { onRemove() }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        // Several buttons in one Form row: without this a tap fires all of them.
        .buttonStyle(.borderless)
    }
}

// MARK: - PhotoPreview

private struct PhotoPreview: View {

    let image: UIImage?
    private let size: CGFloat = 100

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.appSurface)
                .overlay(Circle().stroke(Color.accentPrimary.opacity(0.5), lineWidth: 2))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                    Text("Photo")
                        .font(.caption2)
                }
                .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}
