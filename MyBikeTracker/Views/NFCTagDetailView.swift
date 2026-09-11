import SwiftUI

struct NFCTagDetailView: View {
    @ObservedObject var nfcService: NFCService
    @Environment(\.dismiss) private var dismiss

    let tagID: UUID

    @State private var name: String
    @State private var action: NFCTagAction
    @State private var showDeleteConfirmation = false

    init(nfcService: NFCService, tag: NFCTagRecord) {
        self.nfcService = nfcService
        self.tagID = tag.id
        _name = State(initialValue: tag.name)
        _action = State(initialValue: tag.action)
    }

    var body: some View {
        Form {
            Section {
                TextField(LocalizedStringKey("nfc_tag_name_placeholder"), text: $name)
                    .onChange(of: name) { _, _ in persist() }
            } header: {
                Text(LocalizedStringKey("nfc_tag_name"))
            }

            Section {
                Picker(LocalizedStringKey("nfc_tag_action"), selection: $action) {
                    ForEach(NFCTagAction.allCases) { option in
                        Text(LocalizedStringKey(option.titleKey)).tag(option)
                    }
                }
                .onChange(of: action) { _, _ in persist() }

                Text(LocalizedStringKey(action.descriptionKey))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(LocalizedStringKey("nfc_tag_action"))
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label(LocalizedStringKey("nfc_delete_tag"), systemImage: "trash")
                }
            }
        }
        .navigationTitle(LocalizedStringKey("nfc_edit_tag"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizedStringKey("nfc_delete_tag"), isPresented: $showDeleteConfirmation) {
            Button(LocalizedStringKey("yes"), role: .destructive) {
                nfcService.deleteTag(id: tagID)
                dismiss()
            }
            Button(LocalizedStringKey("no"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("nfc_delete_tag_message"))
        }
    }

    private func persist() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              var tag = nfcService.tags.first(where: { $0.id == tagID }) else { return }
        tag.name = trimmed
        tag.action = action
        nfcService.updateTag(tag)
    }
}
