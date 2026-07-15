import Foundation

extension Copy {
    enum Referral {

        // MARK: - Settings Entry Row

        static var inviteRowTitle: String { RemoteConfigManager.shared.copyString("copy_referral_invite_row_title", default: "Invite friends") }
        static var inviteRowSubtitle: String { RemoteConfigManager.shared.copyString("copy_referral_invite_row_subtitle", default: "Free month of Pro for you and them") }

        // MARK: - Invite Screen

        static var screenTitle: String { RemoteConfigManager.shared.copyString("copy_referral_screen_title", default: "Invite friends") }
        static func bannerTitle(freeUntil: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_referral_banner_title", default: "Laso is free until %@"), freeUntil)
        }
        static var bannerTitleFallback: String { RemoteConfigManager.shared.copyString("copy_referral_banner_title_fallback", default: "Invite friends, earn free Pro") }
        static var bannerSubtitle: String { RemoteConfigManager.shared.copyString("copy_referral_banner_subtitle", default: "You joined early. Every friend you bring makes your free time longer.") }
        static var yourCodeLabel: String { RemoteConfigManager.shared.copyString("copy_referral_your_code_label", default: "YOUR CODE") }
        static var tapToCopy: String { RemoteConfigManager.shared.copyString("copy_referral_tap_to_copy", default: "Tap to copy") }
        static var copied: String { RemoteConfigManager.shared.copyString("copy_referral_copied", default: "Copied") }
        static var rewardLine: String { RemoteConfigManager.shared.copyString("copy_referral_reward_line", default: "1 free month of Pro for both of you, for every friend who joins. Months stack and start when Laso goes paid.") }
        static var noFriendsYet: String { RemoteConfigManager.shared.copyString("copy_referral_no_friends_yet", default: "No friends joined yet") }
        static func friendsJoined(_ count: Int) -> String {
            let template = count == 1
                ? RemoteConfigManager.shared.copyString("copy_referral_friends_joined_one", default: "1 friend joined · 1 month banked")
                : RemoteConfigManager.shared.copyString("copy_referral_friends_joined_many", default: "%d friends joined · %d months banked")
            return count == 1 ? template : String(format: template, count, count)
        }
        static var shareInviteCTA: String { RemoteConfigManager.shared.copyString("copy_referral_share_invite_cta", default: "Share your invite") }
        static var codeLoadError: String { RemoteConfigManager.shared.copyString("copy_referral_code_load_error", default: "Could not load your code. Check your connection and try again.") }

        // MARK: - Share Caption (attached as text next to the rings card image)

        static func shareCaptionYounger(years: Int, code: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_referral_share_caption_younger", default: "My body is %d years younger than my age, says my Apple Watch. Laso is free right now — my code %@ gets you an extra free month of Pro. laso.fit"), years, code)
        }
        static func shareCaptionGeneric(code: String) -> String {
            String(format: RemoteConfigManager.shared.copyString("copy_referral_share_caption_generic", default: "Laso reads my Apple Watch and tells me the one thing to do next, every morning. It is free right now — my code %@ gets you an extra free month of Pro. laso.fit"), code)
        }

        // MARK: - Redeem Errors (shown by ReferralCodeStep)

        static var errorEmptyCode: String { RemoteConfigManager.shared.copyString("copy_referral_error_empty_code", default: "Please enter a referral code.") }
        static var errorAlreadyRedeemed: String { RemoteConfigManager.shared.copyString("copy_referral_error_already_redeemed", default: "You've already used a referral code.") }
        static var errorInvalidCode: String { RemoteConfigManager.shared.copyString("copy_referral_error_invalid_code", default: "Invalid referral code.") }
        static var errorOwnCode: String { RemoteConfigManager.shared.copyString("copy_referral_error_own_code", default: "You can't use your own code.") }
        static var errorAlreadyReferred: String { RemoteConfigManager.shared.copyString("copy_referral_error_already_referred", default: "You've already been referred.") }
        static var errorGeneric: String { RemoteConfigManager.shared.copyString("copy_referral_error_generic", default: "Something went wrong. Try again.") }
    }
}
