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
    @State private var showExportWarning = false

    var body: some View {
        Section(header: Text(LocalizedStringKey("export_import_section"))) {
            // Export button
            Button {
                showExportWarning = true
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
            Button(LocalizedStringKey("ok_button"), role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog(
            LocalizedStringKey("export_privacy_title"),
            isPresented: $showExportWarning,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("export_privacy_confirm")) {
                exportRides()
            }
            Button(LocalizedStringKey("end_ride_continue"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("export_privacy_body"))
        }
    }

    // MARK: - Export logic

    private func exportRides() {
        do {
            let data = try ridesViewModel.exportData()
            let fileName = "mybiketracker_backup_\(formattedDate()).json"
            ProductAnalytics.shared.track(.exportCompleted)
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
                let summary = try ridesViewModel.importBackup(from: data)
                alertTitle = NSLocalizedString("import_export_alert_ok", comment: "")
                alertMessage = String(
                    format: NSLocalizedString("import_success_full", comment: ""),
                    Int64(summary.rides),
                    Int64(summary.bikes),
                    Int64(summary.journals)
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
