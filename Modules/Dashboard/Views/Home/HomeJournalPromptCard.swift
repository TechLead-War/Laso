import SwiftUI

struct HomeJournalPromptCard: View {

    var body: some View {
        let hour = Date.cal.component(.hour, from: Date())
        // Show journal prompt in the evening (after 6pm)
        if hour >= 18 {
            NavigationLink(value: Route.journalEntry) {
                HStack(spacing: DS.space3) {
                    Image(systemName: "square.and.pencil")
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.categoryStress)
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: DS.space1) {
                        Text(Copy.Home.howWasToday)
                            .font(DS.Typography.bodySemibold)
                            .foregroundStyle(AppColour.textPrimary)

                        Text(Copy.Home.journalSubtitle)
                            .font(DS.Typography.callout)
                            .foregroundStyle(AppColour.textSecondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.footnote)
                        .foregroundStyle(AppColour.textTertiary)
                }
                .padding(DS.cardPadding)
                .cardStyle(tint: AppColour.categoryStress)
            }
            .buttonStyle(.dsPress)
            .padding(.horizontal, DS.screenPadding)
        }
    }
}
