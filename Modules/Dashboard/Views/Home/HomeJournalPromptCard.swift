import SwiftUI

struct HomeJournalPromptCard: View {
    var body: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        // Show journal prompt in the evening (after 6pm)
        if hour >= 18 {
            NavigationLink(value: Route.journalEntry) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 24))
                        .foregroundStyle(.purple)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Copy.Home.howWasToday)
                            .font(.system(size: 18).weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(Copy.Home.journalSubtitle)
                            .font(.system(size: 14.4))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13.2))
                        .foregroundStyle(.tertiary)
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: .purple)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.screenPadding)
        }
    }
}
