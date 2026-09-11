import Foundation
import SwiftData

@Model
final class Bike {
    var id: UUID
    var name: String
    var odometerMeters: Double
    var chainIntervalMeters: Double
    var metersAtLastChainService: Double
    var createdAt: Date

    init(
        name: String,
        odometerMeters: Double = 0,
        chainIntervalMeters: Double = 400_000,
        metersAtLastChainService: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.odometerMeters = odometerMeters
        self.chainIntervalMeters = chainIntervalMeters
        self.metersAtLastChainService = metersAtLastChainService
        self.createdAt = Date()
    }

    var metersSinceChainService: Double {
        max(0, odometerMeters - metersAtLastChainService)
    }

    var isChainDue: Bool {
        chainIntervalMeters > 0 && metersSinceChainService >= chainIntervalMeters
    }
}
