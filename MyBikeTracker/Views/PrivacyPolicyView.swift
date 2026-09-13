import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(LocalizedStringKey("privacy_policy_intro"))
                Text(LocalizedStringKey("privacy_policy_location"))
                Text(LocalizedStringKey("privacy_policy_health"))
                Text(LocalizedStringKey("privacy_policy_export"))
                Text(LocalizedStringKey("privacy_policy_analytics"))
                Text(LocalizedStringKey("privacy_policy_third_party"))
            }
            .font(Brand.Font.body)
            .foregroundStyle(Brand.Color.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .brandScreen()
        .navigationTitle(LocalizedStringKey("privacy_policy_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = AppLegal.privacyPolicyURL {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: url) {
                        Image(systemName: "safari")
                    }
                    .accessibilityLabel(LocalizedStringKey("privacy_policy_open_web"))
                }
            }
        }
    }
}
