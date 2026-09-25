//
//  PhotoZoomView.swift
//  Plekio
//
//  Created by Edward Gasparian on 24.08.2026.
//

import SwiftUI

// MARK: - Full-screen photo zoom

struct PhotoZoomView: View {
    let photoId: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.imageLoader) private var imageLoader
    @State private var image: UIImage?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .expandTouchTarget(5)
                    .accessibilityLabel("Close")
                }
                Spacer()
            }
            .padding()
        }
        .task {
            image = await imageLoader.image(for: photoId, targetPointSize: nil)
        }
    }
}
