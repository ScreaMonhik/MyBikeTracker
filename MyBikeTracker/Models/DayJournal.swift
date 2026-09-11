import Foundation
import SwiftData

@Model
final class DayJournal {
    var dayKey: Date
    var note: String
    var photoFileName: String?

    init(dayKey: Date, note: String = "", photoFileName: String? = nil) {
        self.dayKey = dayKey
        self.note = note
        self.photoFileName = photoFileName
    }
}
