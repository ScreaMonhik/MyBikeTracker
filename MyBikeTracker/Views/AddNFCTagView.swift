import SwiftUI

struct AddNFCTagView: View {
    @ObservedObject var nfcService: NFCService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var action: NFCTagAction = .toggleRide
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    init(nfcService: NFCService) {
        self.nfcService = nfcService
        _name = State(initialValue: nfcService.suggestedName())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(LocalizedStringKey("nfc_tag_name_placeholder"), text: $name)
                } header: {
                    Text(LocalizedStringKey("nfc_tag_name"))
                }

                Section {
                    Picker(LocalizedStringKey("nfc_tag_action"), selection: $action) {
                        ForEach(NFCTagAction.allCases) { option in
                            Text(LocalizedStringKey(option.titleKey)).tag(option)
                        }
                    }

                    Text(LocalizedStringKey(action.descriptionKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text(LocalizedStringKey("nfc_tag_action"))
                }

                Section {
                    Button {
                        Task { await scanAndSave() }
                    } label: {
                        Label(
                            LocalizedStringKey("nfc_scan_and_save"),
                            systemImage: isWorking ? "wave.3.right" : "wave.3.right.circle"
                        )
                    }
                    .disabled(!canScan)
                } footer: {
                    Text(LocalizedStringKey("nfc_section_footer"))
                }
            }
            .navigationTitle(LocalizedStringKey("nfc_add_tag_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("cancel_button")) {
                        dismiss()
                    }
                    .disabled(isWorking)
                }
            }
            .alert(LocalizedStringKey("nfc_tag_saved"), isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )) {
                Button(LocalizedStringKey("ok_button"), role: .cancel) {
                    dismiss()
                }
            } message: {
                if let infoMessage {
                    Text(infoMessage)
                }
            }
            .alert(LocalizedStringKey("import_export_alert_error"), isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button(LocalizedStringKey("ok_button"), role: .cancel) {}
            } message: {
                if let errorMessage {
                    Text(errorMessage)
                }
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    private var canScan: Bool {
        !isWorking
            && nfcService.isAvailable
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func scanAndSave() async {
        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await nfcService.provisionTag(name: name, action: action)
            if result.wroteNDEF {
                dismiss()
            } else {
                infoMessage = NSLocalizedString("nfc_readonly_saved", comment: "")
            }
        } catch let error as NFCServiceError where error == .cancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
