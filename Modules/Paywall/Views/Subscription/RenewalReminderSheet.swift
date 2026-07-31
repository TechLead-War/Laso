import SwiftUI

/// Pre renewal notice, shown on the first launch of each day inside the reminder
/// window. Deliberately dismissible: it is a heads-up, not a gate, and the user
/// still has full access while it is on screen.
///
/// Two shapes, chosen by `reminder.willAutoRenew`, because the useful action is
/// the opposite in each case: cancel before an automatic charge, or renew before
/// access lapses.
struct RenewalReminderSheet: View {
    let reminder: RenewalReminderStore.Reminder

    @Environment(\.dismiss) private var dismiss

    private var title: String {
        reminder.willAutoRenew ? Copy.Paywall.renewalChargeTitle : Copy.Paywall.renewalLapseTitle
    }

    private var body_: String {
        let date = reminder.renewalDate.formatted(.dateTime.day().month(.wide).year())
        return reminder.willAutoRenew
            ? Copy.Paywall.renewalChargeBody(date: date)
            : Copy.Paywall.renewalLapseBody(date: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Renewal Reminder Dismiss",
                        type: .shareCard,
                        screen: .paywall,
                        metadata: ["days_remaining": reminder.daysRemaining]
                    )
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.subheadlineSemibold)
                        .foregroundStyle(AppColour.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AppColour.surfaceRaised, in: Circle())
                }
                .accessibilityLabel(Copy.Paywall.renewalDismissLabel)
                Spacer()
            }
            .padding(.horizontal, DS.screenPadding)
            .padding(.top, DS.space4)

            VStack(spacing: DS.space3) {
                Text(title)
                    .font(DS.Typography.title3.weight(.semibold))
                    .foregroundStyle(AppColour.textPrimary)

                Text(body_)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(AppColour.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, DS.space6)
            .padding(.top, DS.space4)

            Image("LaunchIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.vertical, DS.space6)

            Spacer(minLength: 0)

            // Apple owns cancel and renew, so the only honest CTA is a deep link
            // into the App Store subscription settings.
            if let url = URL(string: AppSecrets.URLs.manageSubscriptions) {
                Link(destination: url) {
                    Text(Copy.Paywall.renewalManageCTA)
                        .font(DS.Typography.bodySemibold)
                        .foregroundStyle(AppColour.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColour.info, in: RoundedRectangle(cornerRadius: 14))
                }
                .simultaneousGesture(TapGesture().onEnded {
                    AppAnalytics.shared.trackBlockTap(
                        title: "Manage Subscription",
                        type: .appStoreLink,
                        screen: .paywall,
                        metadata: [
                            "destination": "app_store_subscriptions",
                            "source": "renewal_reminder",
                            "days_remaining": reminder.daysRemaining,
                            "will_auto_renew": reminder.willAutoRenew
                        ]
                    )
                })
                .padding(.horizontal, DS.screenPadding)
                .padding(.bottom, DS.space6)
            }
        }
        .background(AppColour.surfaceBase.ignoresSafeArea())
        .accessibilityIdentifier("screen.renewalReminder")
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            AppAnalytics.shared.trackFeatureOpen(.paywall, metadata: [
                "subscreen": "renewal_reminder",
                "days_remaining": reminder.daysRemaining,
                "will_auto_renew": reminder.willAutoRenew
            ])
        }
        // Without the matching close, paywall open/close pairs go unbalanced and
        // dwell-time analysis silently drops every renewal-reminder session.
        .onDisappear {
            AppAnalytics.shared.trackFeatureClose(.paywall, metadata: [
                "subscreen": "renewal_reminder"
            ])
        }
    }
}

#Preview("Will be charged") {
    RenewalReminderSheet(reminder: .init(
        renewalDate: Date().addingTimeInterval(3 * 86_400),
        daysRemaining: 3,
        willAutoRenew: true
    ))
}

#Preview("Will lapse") {
    RenewalReminderSheet(reminder: .init(
        renewalDate: Date().addingTimeInterval(2 * 86_400),
        daysRemaining: 2,
        willAutoRenew: false
    ))
}
