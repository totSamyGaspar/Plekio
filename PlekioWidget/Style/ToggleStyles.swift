//
//  ToggleStyles.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// Every log control on the widgets is a Toggle(isOn:intent:), not a Button: WidgetKit
// draws the new state the moment it is tapped, while the intent runs in the app,
// and redraws from the snapshot once it's done. A Button would sit dimmed until then.
// The styles draw from `configuration.isOn`; the tap itself is WidgetKit's.

// MARK: - DoseCheckToggleStyle

/// A dose's own check, as on Today's cards.
struct DoseCheckToggleStyle: ToggleStyle {
    var isMissed = false
    var onHero = false
    var size: CGFloat = 22

    func makeBody(configuration: Configuration) -> some View {
        DoseMark(
            status: configuration.isOn ? .taken : .pending,
            isMissed: isMissed && !configuration.isOn,
            onHero: onHero,
            size: size
        )
        .frame(width: size + 6, height: size + 6)
        .contentShape(Rectangle())
    }
}

// MARK: - DoseRowToggleStyle

/// A whole medication line on the up-next card: the mark, then the label, struck
/// through once taken.
struct DoseRowToggleStyle: ToggleStyle {
    var isMissed = false
    var onHero = false

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 7) {
            DoseMark(
                status: configuration.isOn ? .taken : .pending,
                isMissed: isMissed && !configuration.isOn,
                onHero: onHero,
                size: 15
            )
            configuration.label
                .strikethrough(configuration.isOn)
                .opacity(configuration.isOn ? 0.6 : 1)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Log all

/// The hero card's white "LOG ALL" pill; a check once tapped.
struct HeroPillToggleStyle: ToggleStyle {
    let title: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        if configuration.isOn {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Color.onHeroButton)
                .frame(minWidth: 44)
                .padding(.vertical, 8)
                .background(Color.white, in: Capsule())
                .widgetAccentable()
        } else {
            HeroPill(title: title)
        }
    }
}

/// The small widget's round check; filled once tapped.
struct HeroCheckToggleStyle: ToggleStyle {
    let label: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: "checkmark")
            .font(.system(size: 15, weight: .heavy))
            .foregroundStyle(configuration.isOn ? Color.white : Color.onHeroButton)
            .frame(width: 36, height: 36)
            .background(configuration.isOn ? Color.onHeroButton : Color.white, in: Circle())
            .widgetAccentable()
            .accessibilityLabel(Text(label))
    }
}

/// The missed card's red "Take now"; a check once tapped.
struct MissedTakeToggleStyle: ToggleStyle {
    let title: LocalizedStringKey

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if configuration.isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
            } else {
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.warningAccent, in: Capsule())
        .widgetAccentable()
    }
}
