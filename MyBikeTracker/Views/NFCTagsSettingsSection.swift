import SwiftUI

struct NFCTagsSettingsSection: View {
    @ObservedObject var nfcService: NFCService
    @State private var isAddingTag = false

    var body: some View {
        Section {
            if nfcService.tags.isEmpty {
                Text(LocalizedStringKey("nfc_no_tags"))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(nfcService.tags) { tag in
                    NavigationLink {
                        NFCTagDetailView(nfcService: nfcService, tag: tag)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tag.name)
                            Text(LocalizedStringKey(tag.action.titleKey))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: nfcService.deleteTags)
            }

            if nfcService.isAvailable {
                Button {
                    isAddingTag = true
                } label: {
                    Label(LocalizedStringKey("nfc_add_tag"), systemImage: "plus.circle")
                }
            }
        } header: {
            Text(LocalizedStringKey("nfc_section"))
        } footer: {
            Text(LocalizedStringKey(nfcService.isAvailable ? "nfc_section_footer" : "nfc_not_available_message"))
        }
        .sheet(isPresented: $isAddingTag) {
            AddNFCTagView(nfcService: nfcService)
        }
    }
}
