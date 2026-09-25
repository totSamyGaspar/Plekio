//
//  AppLogo.swift
//  Plekio
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

#Preview {
    AppLogo(size: 120)
        .padding(40)
        .background(Color.appBackground)
}
