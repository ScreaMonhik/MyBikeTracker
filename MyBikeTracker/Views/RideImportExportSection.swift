//
//  RideImportExportSection.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 06.03.2025.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Import / Export Section

struct RideImportExportSection: View {
    @ObservedObject var ridesViewModel: RidesViewModel

    // Export
    @State private var exportItem: ExportItem?
    // Import
    @State private var showFilePicker = false
    // Alerts
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    var body: some View {
        Section(header: Text(LocalizedStringKey("export_import_section"))) {
            // Export button
            Button {
                exportRides()
            } label: {
                Label(LocalizedStringKey("export_rides_button"), systemImage: "square.and.arrow.up")
            }

            // Import button
            Button {
                showFilePicker = true
            } label: {
                Label(LocalizedStringKey("import_rides_button"), systemImage: "square.and.arrow.down")
            }
        }
        // Share sheet for export
        .sheet(item: $exportItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        // File picker for import
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button(LocalizedStringKey("no"), role: .cancel) {}    // reuse "OK"-like dismiss
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Export logic

    private func exportRides() {
        do {
            let data = try ridesViewModel.exportData()
            let fileName = "rides_\(formattedDate()).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: url)
            exportItem = ExportItem(url: url)
        } catch {
            showError(error)
        }
    }

    // MARK: - Import logic

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            showError(error)

        case .success(let urls):
            guard let url = urls.first else { return }

            // Security-scoped resource access required for Files-picked URLs
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: url)
                let count = try ridesViewModel.importRides(from: data)
                alertTitle = NSLocalizedString("import_export_alert_ok", comment: "")
                alertMessage = String(
                    format: NSLocalizedString("import_success", comment: ""),
                    count
                )
                showAlert = true
            } catch {
                showError(error)
            }
        }
    }

    // MARK: - Helpers

    private func showError(_ error: Error) {
        alertTitle = NSLocalizedString("import_export_alert_error", comment: "")
        alertMessage = String(
            format: NSLocalizedString("import_export_error", comment: ""),
            error.localizedDescription
        )
        showAlert = true
    }

    private func formattedDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}

// MARK: - Identifiable wrapper for the export URL

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - ShareSheet (UIActivityViewController wrapper)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
