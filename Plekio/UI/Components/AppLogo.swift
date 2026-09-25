//
//  AppLogo.swift
//  Plekio
//
//  Created by Edward Gasparian on 21.09.2026.
//

import SwiftUI

struct AppLogo: View {

    let size: CGFloat
    var tint: Color = .accentPrimary

    var body: some View {
        Image(decorative: AppBrand.logoAssetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
    }
}

// MARK: - Preview

#Preview {
    AppLogo(size: 120)
        .padding(40)
        .background(Color.appBackground)
}
