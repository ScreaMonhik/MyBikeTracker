//
//  TimeFormatting.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import Foundation

extension TimeInterval {
    /// Форматирует TimeInterval как "HH:MM:SS"
    var formattedAsTimer: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "00:00:00"
    }
}
