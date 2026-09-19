//
//  DiaryTodayCard.swift
//  PillFlow
//

import SwiftUI

/// Today's check-in: an invitation to log one, or a summary of the one logged.
///
/// The two states were two `private var`s on DiaryView with a `Group` picking
/// between them. Here they are one view with one decision, and the four quick
/// moods come in as data rather than sitting in the screen above.
struct DiaryTodayCard: View {
    
    struct QuickMood: Identifiable {
        let label: LocalizedStringResource
        let emoji: String
        let mood: DiaryMood
        
        var id: DiaryMood { mood }
    }
    
    /// Nil until the user has logged something today.
    let entry: DiaryEntry?
    let quickMoods: [QuickMood]
    
    let onQuickLog: (DiaryMood) -> Void
    let onEdit: (DiaryEntry) -> Void
    
    var body: some View {
        Group {
            if let entry {
                logged(entry)
            } else {
                pending
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Not logged yet
    
    private var pending: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles").foregroundColor(.yellow)
                Text("TODAY'S WELLNESS CHECK-IN IS PENDING")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.textPrimary.opacity(0.7))
            }
            Text("How are you feeling right now? Tap a mood to log quickly or fill in detailed notes & photos.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
            
            HStack(spacing: 10) {
                ForEach(quickMoods) { item in
                    Button {
                        withAnimation { onQuickLog(item.mood) }
                    } label: {
                        VStack(spacing: 4) {
                            Text(verbatim: item.emoji)
                            Text(item.label)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.appBackground)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.accentPrimary.opacity(0.2), lineWidth: 1))
    }
    
    // MARK: - Already logged
    
    private func logged(_ entry: DiaryEntry) -> some View {
        let mood = DiaryMood(rawValue: entry.moodLabel)
        let quote = entry.displayCaption
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TODAY'S CHECK-IN LOGGED")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(.accentPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentPrimary.opacity(0.12))
                    .clipShape(Capsule())
                Spacer()
                Text("at \(entry.checkInDate.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color.accentPrimary.opacity(0.15)).frame(width: 40, height: 40)
                    Text(mood?.emoji ?? "📝").font(.title3)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Self.summaryLine(entry)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.textPrimary)
                    if !quote.isEmpty {
                        Text("“\(quote)”")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            
            HStack {
                Spacer()
                Button {
                    onEdit(entry)
                } label: {
                    Label("Edit Entry", systemImage: "pencil")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.textPrimary.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(Color.textPrimary.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.appSurface)
        .cornerRadius(20)
    }
    
    /// Built by concatenation rather than interpolation: each piece is its own
    /// translatable string, and the middle one changes with the kind of entry.
    private static func summaryLine(_ entry: DiaryEntry) -> Text {
        var line = Text("Mood: \(entry.moodTitle)") + Text(verbatim: " • ")
        line = line + (entry.isQuickLog ? Text("Quick log") : Text("Energy: \(entry.energyLevel)/5"))
        
        if !entry.photoIds.isEmpty {
            line = line + Text(verbatim: " • ") + Text("\(entry.photoIds.count) photos attached")
        }
        return line
    }
}

extension DiaryTodayCard.QuickMood {
    
    /// The four moods the pending card offers.
    static let standard: [DiaryTodayCard.QuickMood] = [
        .init(label: "Great", emoji: "☀️", mood: .great),
        .init(label: "Good", emoji: "🙂", mood: .good),
        .init(label: "Okay", emoji: "😊", mood: .neutral),
        .init(label: "Tired", emoji: "😴", mood: .exhausted),
    ]
}
