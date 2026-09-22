//
//  DayPreview.swift
//  Plekio
//

import SwiftUI

/// Slide 2: the day split into morning, afternoon and evening, with two doses
/// already behind and the next one waiting.
///
/// The logged rows are dimmed rather than removed: the point of the slide is
/// that the day is one list you move down, not a queue that empties.
struct DayPreview: View {

    var body: some View {
        VStack(spacing: 10) {
            section(title: "Morning", tally: "2 / 2", isDone: true)
            row(time: "08:00", name: "Bisoprolol", state: .logged)
            row(time: "08:00", name: "Aspirin", state: .logged)

            section(title: "Afternoon", tally: "0 / 1", isDone: false)
                .padding(.top, 6)
            row(time: "14:00", name: "Ibuprofen", state: .next)

            section(title: "Evening", tally: nil, isDone: false)
                .padding(.top, 6)
            row(time: "20:00", name: "Bisoprolol", state: .waiting)
        }
        .frame(width: 306)
    }

    private enum RowState { case logged, next, waiting }

    private func section(title: LocalizedStringResource, tally: String?, isDone: Bool) -> some View {
        HStack {
            OnboardingCaption(text: title)
            Spacer(minLength: 0)
            if let tally {
                Text(verbatim: tally)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isDone ? .accentPrimary : .textSecondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private func row(time: String, name: String, state: RowState) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: time)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(state == .next ? .accentPrimary : .textPrimary)
                .frame(width: 46, alignment: .leading)

            Text(verbatim: name)
                .font(.system(size: 15, weight: state == .next ? .semibold : .regular))
                .foregroundColor(.textPrimary)

            Spacer(minLength: 0)

            check(state)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Color.appSurface)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentPrimary.opacity(state == .next ? 0.4 : 0), lineWidth: 1)
        )
        .opacity(state == .logged ? 0.45 : 1)
    }

    @ViewBuilder
    private func check(_ state: RowState) -> some View {
        switch state {
        case .logged:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.onAccent)
                .frame(width: 26, height: 26)
                .background(Color.accentPrimary)
                .clipShape(.circle)
        case .next:
            Circle().stroke(Color.accentPrimary, lineWidth: 2).frame(width: 26, height: 26)
        case .waiting:
            Circle().stroke(Color.textPrimary.opacity(0.18), lineWidth: 2).frame(width: 26, height: 26)
        }
    }
}

#Preview {
    DayPreview()
        .padding(40)
        .background(Color.appBackground)
}
