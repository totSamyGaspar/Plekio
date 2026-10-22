//
//  WidgetStyle.swift
//  PlekioWidget
//
//  Created by Edward Gasparian on 21.10.2026.
//

import SwiftUI
import WidgetKit

// MARK: - Fonts

extension Font {

    /// The app's serif headings (medication names, "Day complete").
    static func widgetSerif(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

// MARK: - Surface

extension Color {

    /// The widget's own background. Light: the app's screen cream, as pure white
    /// glares on a Home Screen. Dark: the card colour; the app's near-black screen
    /// colour would read as a hole in a dark Home Screen.
    /// Keep in sync with Assets.xcassets/WidgetBackground, which iOS draws while the
    /// widget loads and in edit mode.
    static let widgetSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.19, alpha: 1)
            : UIColor(red: 0.953, green: 0.945, blue: 0.914, alpha: 1)
    })
}

// MARK: - Hero

/// Ink of the white "LOG ALL" button on the hero card (UpNextHeroCard).
extension Color {
    static let onHeroButton = Color(red: 0.05, green: 0.3, blue: 0.2)
}

/// The Today hero card's time-of-day gradient, by the entry's hour, not the clock's.
struct HeroBackground: View {
    let date: Date

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var colors: [Color] {
        switch Calendar.autoupdatingCurrent.component(.hour, from: date) {
        case 5..<12: [.heroMorningStart, .heroMorningEnd]
        case 12..<18: [.heroNoonStart, .heroNoonEnd]
        default: [.heroEveningStart, .heroEveningEnd]
        }
    }

    var body: some View {
        // Tinted and clear Home Screens draw their own background; a gradient would only muddy it.
        if renderingMode == .fullColor {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            Color.clear
        }
    }
}

/// The dark capsule label at the top of a hero card ("UP NEXT TODAY").
struct HeroChip: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            // Shrinks before it wraps: whatever sits beside it keeps its line.
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .font(.system(size: 10, weight: .heavy))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.15), in: Capsule())
    }
}

/// The white pill button of the hero card; stage 4 wraps it in an intent button.
struct HeroPill: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .heavy))
            .foregroundStyle(Color.onHeroButton)
            .lineLimit(1)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Color.white, in: Capsule())
            .widgetAccentable()
    }
}

// MARK: - Progress

/// The app's progress ring (CircularProgressView), without animation: a widget is a still.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 8
    var track: Color = .accentPrimary.opacity(0.2)
    var ring: [Color] = [.accentPrimary, .accentSecondary]

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    LinearGradient(colors: ring, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth - 1, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
        .padding(lineWidth / 2)
    }
}

// MARK: - Dose mark

/// A dose's state as a symbol, the same ones Today uses.
struct DoseMark: View {
    let status: WidgetSnapshot.Status
    var isMissed = false
    /// On a hero gradient everything is white; on a card it takes the app's tints.
    var onHero = false
    var size: CGFloat = 18

    private var symbol: String {
        switch status {
        case .taken: "checkmark.circle.fill"
        case .skipped: "minus.circle"
        case .pending: onHero ? "circle.dotted.circle" : "checkmark.circle"
        }
    }

    private var tint: Color {
        if onHero { return status == .pending ? .white : .white.opacity(0.6) }
        switch status {
        case .taken: return .accentPrimary
        case .skipped: return .textSecondary
        case .pending: return isMissed ? .warningAccent : .textTertiary
        }
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(tint)
            .widgetAccentable(status == .taken)
            .accessibilityHidden(true)
    }
}

// MARK: - Logo

/// On every widget, so it reads as Plekio's at a glance. White on the hero gradient.
struct WidgetLogo: View {
    var size: CGFloat = 16
    var tint: Color = .accentPrimary

    var body: some View {
        Image("Logo")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .widgetAccentable()
            .accessibilityHidden(true)
    }
}

// MARK: - Formatting

extension Date {
    /// "08:00" / "8:00 AM", as the locale writes it.
    var widgetTime: Text {
        Text(self, format: .dateTime.hour().minute())
    }
}

extension WidgetSnapshot.Period {
    /// The keys DayPeriod uses in the app.
    var title: LocalizedStringKey {
        switch self {
        case .morning: "Morning"
        case .afternoon: "Afternoon"
        case .evening: "Evening"
        }
    }
}
