import PhotosUI
import SwiftUI
import UIKit

struct DayJournalSection: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    let date: Date

    @State private var note: String = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        Section {
            TextField(LocalizedStringKey("day_note_placeholder"), text: $note, axis: .vertical)
                .lineLimit(3...8)
                .onChange(of: note) { _, newValue in
                    ridesViewModel.updateNote(newValue, for: date)
                }

            if let photo = ridesViewModel.photo(for: date) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(maxHeight: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button(role: .destructive) {
                    ridesViewModel.setPhoto(nil, for: date)
                } label: {
                    Label(LocalizedStringKey("day_photo_remove"), systemImage: "trash")
                }
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(LocalizedStringKey("day_photo_add"), systemImage: "photo")
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label(LocalizedStringKey("day_photo_camera"), systemImage: "camera")
                }
            }
        } header: {
            Text(LocalizedStringKey("day_note_title"))
        }
        .onAppear {
            note = ridesViewModel.journal(for: date)?.note ?? ""
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    ridesViewModel.setPhoto(image, for: date)
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                if let image {
                    ridesViewModel.setPhoto(image, for: date)
                }
            }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage?) -> Void

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onImage(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            onImage(info[.originalImage] as? UIImage)
        }
    }
}
