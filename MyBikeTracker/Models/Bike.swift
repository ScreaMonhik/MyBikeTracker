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
    /// Speeds below this (km/h) count as slow on this bike's heatmap.
    var paceSlowMaxKmh: Double = PaceScale.default.slowMaxKmh
    /// Speeds below this (km/h) count as medium; above is fast.
    var paceMediumMaxKmh: Double = PaceScale.default.mediumMaxKmh

    init(
        name: String,
        odometerMeters: Double = 0,
        chainIntervalMeters: Double = 400_000,
        metersAtLastChainService: Double = 0,
        paceSlowMaxKmh: Double = PaceScale.default.slowMaxKmh,
        paceMediumMaxKmh: Double = PaceScale.default.mediumMaxKmh
    ) {
        self.id = UUID()
        self.name = name
        self.odometerMeters = odometerMeters
        self.chainIntervalMeters = chainIntervalMeters
        self.metersAtLastChainService = metersAtLastChainService
        self.createdAt = Date()
        self.paceSlowMaxKmh = paceSlowMaxKmh
        self.paceMediumMaxKmh = paceMediumMaxKmh
    }

    var paceScale: PaceScale {
        PaceScale(slowMaxKmh: paceSlowMaxKmh, mediumMaxKmh: paceMediumMaxKmh).sanitized
    }

    var metersSinceChainService: Double {
        max(0, odometerMeters - metersAtLastChainService)
    }

    var isChainDue: Bool {
        chainIntervalMeters > 0 && metersSinceChainService >= chainIntervalMeters
    }
}
