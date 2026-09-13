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
        Self.timerFormatter.string(from: self) ?? "00:00:00"
    }

    /// Short ride length for cards: `0:07`, `12:07`, `1:12:05`.
    var formattedAsCompactDuration: String {
        let total = max(0, Int(rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static let timerFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
}
