//
//  ReportPreview.swift
//  Plekio
//

import SwiftUI

/// Slide 5: the exported document, as a sheet of paper.
///
/// The one preview that does not follow the palette, for the same reason
/// `ReportStyle` does not: a report is black on white whatever theme the phone
/// is in, and a sheet that went dark with the app would stop reading as a
/// document. The white rectangle is the whole argument of the slide — it is
/// recognisable before a word of it is read.
struct ReportPreview: View {

    /// Widths of the ruled lines standing in for body text, as fractions.
    private let medication: [CGFloat] = [0.80, 0.64]
    private let pressure: [CGFloat] = [0.92, 0.74, 0.86]
    private let diary: [CGFloat] = [0.88, 0.56]

    var body: some View {
        VStack(spacing: 16) {
            sheet
            shareChip
        }
    }

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

            block(title: "Medications", lines: medication, showsRate: true)
            block(title: "Blood Pressure", lines: pressure, showsRate: false)
            block(title: "Diary", lines: diary, showsRate: false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(width: 214)
        .background(Color.white)
        .clipShape(.rect(cornerRadius: 10))
        .shadow(color: .black.opacity(0.55), radius: 22, y: 9)
    }

    private func block(title: LocalizedStringResource, lines: [CGFloat], showsRate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Self.ink)

            if showsRate {
                HStack(spacing: 6) {
                    Capsule().fill(Self.paperRule).frame(height: 4)
                    Text(verbatim: "92%")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Self.paperText)
                }
            }

            ForEach(Array(lines.enumerated()), id: \.offset) { _, width in
                Capsule()
                    .fill(Self.paperLine)
                    .frame(width: 178 * width, height: 4)
            }
        }
    }

    private var shareChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 13, weight: .semibold))
            Text("Share PDF")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundColor(.accentPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.accentPrimary.opacity(0.14))
        .clipShape(.capsule)
    }

    // Paper colours, spelled out for the same reason `ReportStyle` spells its
    // own out: read from the palette they would answer differently in each
    // theme, and this sheet has no theme.
    private static let ink = Color(red: 0.0, green: 0.647, blue: 0.580)
    private static let paperText = Color(red: 0.078, green: 0.078, blue: 0.075)
    private static let paperMuted = Color(red: 0.420, green: 0.447, blue: 0.502)
    private static let paperRule = Color(red: 0.898, green: 0.906, blue: 0.922)
    private static let paperLine = Color(red: 0.929, green: 0.937, blue: 0.949)
}

#Preview {
    ReportPreview()
        .padding(40)
        .background(Color.appBackground)
}
