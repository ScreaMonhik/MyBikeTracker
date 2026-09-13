import SwiftUI

struct PersistenceIssueBanner: View {
    let issue: PersistenceIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(issue.kind == .ephemeralFallback ? "store_error_title" : "store_backup_title"))
                .font(Brand.Font.headline)
                .foregroundStyle(Brand.Color.ink)
            Text(LocalizedStringKey(issue.kind == .ephemeralFallback ? "store_error_body" : "store_backup_body"))
                .font(Brand.Font.body)
                .foregroundStyle(Brand.Color.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.Color.amber.opacity(0.18), in: RoundedRectangle(cornerRadius: Brand.Radius.md, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}
