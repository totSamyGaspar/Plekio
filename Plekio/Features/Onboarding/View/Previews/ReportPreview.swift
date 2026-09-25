//
//  ReportPreview.swift
//  Plekio
//
//  Created by Edward Gasparian on 22.09.2026.
//

import SwiftUI

/// Onboarding slide 5: the exported report as a sheet of paper.
/// Always black on white, like `ReportStyle`, regardless of the app theme.
struct ReportPreview: View {

    // MARK: - Properties

    /// Widths of the ruled lines standing in for body text, as fractions.
    private let medication: [CGFloat] = [0.80, 0.64]
    private let pressure: [CGFloat] = [0.92, 0.74, 0.86]
    private let diary: [CGFloat] = [0.88, 0.56]

    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var now = Frame.opening
    @State private var touch = TouchPhase.none

    private struct Frame {
        var sections = 0
        var rate = 0
        var isShared = false

        static let opening = Frame()
        static let still = Frame(sections: 3, rate: 92)
    }

    private var shown: Frame { reduceMotion ? .still : now }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            sheet
            shareChip
        }
        .task(id: isActive) {
            guard isActive, !reduceMotion else { return }
            await Demo.loop(scene) { now = .opening; touch = .none }
        }
    }

    // MARK: - Scene

    private func scene() async throws {
        try await Demo.wait(0.5)
        for count in 1...3 {
            withAnimation(.easeOut(duration: 0.3)) { now.sections = count }
            if count == 1 {
                withAnimation(.easeOut(duration: 0.9).delay(0.15)) { now.rate = 92 }
            }
            try await Demo.wait(0.55)
        }

        try await Demo.wait(0.6)
        try await Demo.tap($touch) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { now.isShared = true }
        }

        try await Demo.wait(2.4)
        withAnimation(.easeInOut(duration: 0.45)) { now = .opening }
        try await Demo.wait(0.6)
    }

    // MARK: - Subviews

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 6) {
                AppLogo(size: 13, tint: Self.ink)
                Text(AppBrand.name)
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundColor(Self.ink)
            }

            Text("Health report")
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundColor(Self.paperText)

            Text(verbatim: "1 — 30")
                .font(.system(size: 8))
                .foregroundColor(Self.paperMuted)

            Rectangle().fill(Self.paperRule).frame(height: 1)

            block(0, title: "Medications", lines: medication, showsRate: true)
            block(1, title: "Blood Pressure", lines: pressure, showsRate: false)
            block(2, title: "Diary", lines: diary, showsRate: false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(width: 214)
        .background(Color.white)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 9)
        .offset(y: shown.isShared ? -6 : 0)
        .scaleEffect(shown.isShared ? 0.97 : 1)
    }

    /// A report section, hidden until the scene reaches `index`.
    private func block(_ index: Int, title: LocalizedStringResource, lines: [CGFloat], showsRate: Bool) -> some View {
        let isWritten = shown.sections > index

        return VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Self.ink)
                .opacity(isWritten ? 1 : 0)

            if showsRate {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Self.paperRule)
                        .frame(height: 4)
                        .overlay(alignment: .leading) {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Self.ink)
                                    .frame(width: proxy.size.width * CGFloat(shown.rate) / 100)
                            }
                        }
                    Text(verbatim: "\(shown.rate)%")
                        .font(.system(size: 8, weight: .bold))
                        .monospacedDigit()
                        .foregroundColor(Self.paperText)
                        .contentTransition(.numericText(value: Double(shown.rate)))
                }
                .opacity(isWritten ? 1 : 0)
            }

            ForEach(Array(lines.enumerated()), id: \.offset) { line, width in
                Capsule()
                    .fill(Self.paperLine)
                    .frame(width: 178 * width, height: 4)
                    .scaleEffect(x: isWritten ? 1 : 0, anchor: .leading)
                    .animation(.easeOut(duration: 0.35).delay(Double(line) * 0.09), value: isWritten)
            }
        }
    }

    private var shareChip: some View {
        HStack(spacing: 8) {
            Image(systemName: shown.isShared ? "checkmark" : "square.and.arrow.up")
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
            ZStack {
                if shown.isShared {
                    Text("Sent").transition(.blurReplace)
                } else {
                    Text("Share PDF").transition(.blurReplace)
                }
            }
            .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.accentPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.accentPrimary.opacity(shown.isShared ? 0.22 : 0.14))
        .clipShape(.capsule)
        .demoTouch(touch, pressScale: 0.92)
    }

    // MARK: - Paper Colors

    // Fixed, not palette colors: the paper must look the same in every theme.
    private static let ink = Color(red: 0.0, green: 0.647, blue: 0.580)
    private static let paperText = Color(red: 0.078, green: 0.078, blue: 0.075)
    private static let paperMuted = Color(red: 0.420, green: 0.447, blue: 0.502)
    private static let paperRule = Color(red: 0.898, green: 0.906, blue: 0.922)
    private static let paperLine = Color(red: 0.929, green: 0.937, blue: 0.949)
}

// MARK: - Preview

#Preview {
    ReportPreview()
        .padding(40)
        .background(Color.appBackground)
}
