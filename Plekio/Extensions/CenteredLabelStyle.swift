//
//  CenteredLabelStyle.swift
//  Plekio
//

import SwiftUI

/// A `Label` whose icon stays vertically centred against its title.
///
/// The stock style aligns the icon to the title's *first line*. That reads fine
/// while the title fits on one line and looks broken the moment it wraps — the
/// icon stays up beside the top line instead of the block as a whole. Button
/// labels wrap in most of the nine translations, so they use this.
struct CenteredLabelStyle: LabelStyle {
    var spacing: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        // A plain HStack, whose default alignment is exactly the centring the
        // stock label gives up in order to sit on the text baseline.
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == CenteredLabelStyle {
    static var centered: CenteredLabelStyle { CenteredLabelStyle() }
}
