//
//  RideCalendarView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 05.03.2025.
//

import SwiftUI

struct RideCalendarView: View {
    let rides: [Ride]

    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth: Date = {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
    }()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdaySymbols: [String] = {
        var cal = Calendar.current
        cal.locale = Locale.current
        // Start from Monday
        var symbols = cal.shortStandaloneWeekdaySymbols
        // Rotate so Monday is first
        let firstWeekday = cal.firstWeekday // 1 = Sunday
        let offset = (2 - firstWeekday + 7) % 7 // shift to Monday
        return Array(symbols[offset...] + symbols[..<offset])
    }()

    /// Set of calendar days (year+month+day) that have at least one ride
    private var rideDays: Set<DateComponents> {
        var result = Set<DateComponents>()
        for ride in rides {
            let comps = calendar.dateComponents([.year, .month, .day], from: ride.startDate)
            result.insert(comps)
        }
        return result
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        formatter.locale = Locale.current
        return formatter.string(from: displayedMonth).capitalized
    }

    /// All days to display in the grid (including leading/trailing blanks)
    private var gridDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekdayOfMonth = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }

        // How many empty cells before the 1st: offset to make Monday = 0
        let offset = (firstWeekdayOfMonth - 2 + 7) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)

        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        // Pad to full rows
        let remainder = days.count % 7
        if remainder != 0 {
            days += Array(repeating: nil, count: 7 - remainder)
        }

        return days
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Month navigation
                HStack {
                    Button {
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .padding(8)
                    }

                    Spacer()

                    Text(monthTitle)
                        .font(.headline)
                        .animation(.none, value: monthTitle)

                    Spacer()

                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .padding(8)
                    }
                }
                .padding(.horizontal)

                // Weekday headers
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                // Day cells
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            DayCell(date: day, hasRide: hasRide(on: day), isToday: isToday(day))
                        } else {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Legend
                HStack(spacing: 24) {
                    legendItem(color: .green, label: NSLocalizedString("calendar_legend_ride", comment: ""))
                    legendItem(color: .gray.opacity(0.4), label: NSLocalizedString("calendar_legend_no_ride", comment: ""))
                }
                .padding(.bottom)
            }
            .navigationTitle(NSLocalizedString("calendar_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("calendar_close", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func hasRide(on date: Date) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return rideDays.contains(comps)
    }

    private func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Day Cell

private struct DayCell: View {
    let date: Date
    let hasRide: Bool
    let isToday: Bool

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(fillColor)
            Text("\(dayNumber)")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundColor(textColor)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var fillColor: Color {
        if hasRide {
            return .green
        } else {
            return Color(.systemGray5)
        }
    }

    private var textColor: Color {
        if hasRide {
            return .white
        } else {
            return .primary
        }
    }
}
