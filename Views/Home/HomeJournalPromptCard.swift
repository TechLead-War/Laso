import SwiftUI

struct HomeJournalPromptCard: View {
    var body: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        // Show journal prompt in the evening (after 6pm)
        if hour >= 18 {
            NavigationLink(value: Route.journalEntry) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(.purple)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Home.howWasToday)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(Copy.Home.journalSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: .purple)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
}
