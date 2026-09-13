import Foundation

struct AppBackupDTO: Codable {
    var version: Int
    var exportedAt: Date
    var rides: [RideExportDTO]
    var bikes: [BikeExportDTO]
    var journals: [JournalExportDTO]
}

struct BikeExportDTO: Codable {
    var id: UUID
    var name: String
    var odometerMeters: Double
    var chainIntervalMeters: Double
    var metersAtLastChainService: Double
    var createdAt: Date

    init(bike: Bike) {
        id = bike.id
        name = bike.name
        odometerMeters = bike.odometerMeters
        chainIntervalMeters = bike.chainIntervalMeters
        metersAtLastChainService = bike.metersAtLastChainService
        createdAt = bike.createdAt
    }
}

struct JournalExportDTO: Codable {
    var dayKey: Date
    var note: String
    var photoFileName: String?
    var photoJPEGBase64: String?

    init(journal: DayJournal, photoJPEG: Data?) {
        dayKey = journal.dayKey
        note = journal.note
        photoFileName = journal.photoFileName
        photoJPEGBase64 = photoJPEG?.base64EncodedString()
    }
}

struct ImportSummary {
    var rides: Int
    var bikes: Int
    var journals: Int

    var total: Int { rides + bikes + journals }
}
