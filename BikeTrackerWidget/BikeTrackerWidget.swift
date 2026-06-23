//
//  BikeTrackerWidget.swift
//  BikeTrackerWidget
//
//  Created by Dima Sunko on 06.03.2026.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct BikeWidgetTimelineEntry: TimelineEntry {
    let date: Date
    let yearlyKm: Double
    let rideDays: Set<DateComponents>
    let allEntries: [RideWidgetEntry]
}

// MARK: - Timeline Provider

struct BikeWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> BikeWidgetTimelineEntry {
        BikeWidgetTimelineEntry(date: .now, yearlyKm: 342.5, rideDays: [], allEntries: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (BikeWidgetTimelineEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BikeWidgetTimelineEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh at next midnight so the calendar stays accurate
        let midnight = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }

    private func makeEntry() -> BikeWidgetTimelineEntry {
        let entries = RideWidgetEntry.load()
        return BikeWidgetTimelineEntry(
            date: .now,
            yearlyKm: RideWidgetEntry.yearlyDistanceKm(from: entries),
            rideDays: RideWidgetEntry.rideDays(from: entries),
            allEntries: entries
        )
    }
}

// MARK: - Small Widget  (systemSmall)

struct YearlyKmWidget: Widget {
    let kind = "YearlyKmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BikeWidgetProvider()) { entry in
            SmallWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Yearly Distance")
        .description("Total kilometers ridden this year.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Medium Widget  (systemMedium)

struct YearlyKmCalendarWidget: Widget {
    let kind = "YearlyKmCalendarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BikeWidgetProvider()) { entry in
            MediumWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Yearly Distance + Calendar")
        .description("Total km this year with a monthly ride calendar.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: BikeWidgetTimelineEntry

    var body: some View {
        VStack(spacing: 6) {
            // Icon + label
            HStack(spacing: 6) {
                Image(systemName: "bicycle")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Text(verbatim: yearString)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            // Big km number
            Text(formattedKm)
                .font(.system(size: 40, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("km")
                .font(.headline.bold())
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var formattedKm: String {
        String(format: "%.1f", entry.yearlyKm)
    }

    private var yearString: String {
        String(Calendar.current.component(.year, from: .now))
    }
}

// MARK: - Medium Widget View  (side-by-side: km stat | calendar)

struct MediumWidgetView: View {
    let entry: BikeWidgetTimelineEntry

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    private var displayedMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
    }

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        fmt.locale = Locale.current
        return fmt.string(from: displayedMonth).capitalized
    }

    private var weekdayHeaders: [String] {
        var cal = Calendar.current
        cal.locale = Locale.current
        let symbols = cal.shortStandaloneWeekdaySymbols
        let offset = (2 - cal.firstWeekday + 7) % 7
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var gridDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthInterval.start).weekday
        else { return [] }
        let offset = (firstWeekday - 2 + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)
        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        let rem = days.count % 7
        if rem != 0 { days += Array(repeating: nil, count: 7 - rem) }
        return days
    }

    var body: some View {
        HStack(spacing: 10) {
            // LEFT – yearly km stat
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "bicycle")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    Text(verbatim: String(Calendar.current.component(.year, from: .now)))
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(String(format: "%.1f", entry.yearlyKm))
                    .font(.system(size: 36, weight: .black, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Text("km this year")
                    .font(.caption.bold())
                    .foregroundStyle(.green)

                Spacer()

                let monthRides = ridesThisMonth()
                HStack(spacing: 3) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(verbatim: "\(monthRides) ")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    + Text("this month")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // RIGHT – calendar
            VStack(spacing: 2) {
                Text(monthTitle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Weekday headers
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(weekdayHeaders, id: \.self) { sym in
                        Text(String(sym.prefix(1)))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Day cells
                LazyVGrid(columns: columns, spacing: 1) {
                    ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                        if let day {
                            CalendarDayCell(date: day, hasRide: hasRide(on: day))
                        } else {
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
    }

    private func hasRide(on date: Date) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return entry.rideDays.contains(comps)
    }

    private func ridesThisMonth() -> Int {
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return entry.allEntries.filter {
            calendar.component(.year, from: $0.startDate) == year &&
            calendar.component(.month, from: $0.startDate) == month
        }.count
    }
}

// MARK: - Calendar Day Cell (widget version)

private struct CalendarDayCell: View {
    let date: Date
    let hasRide: Bool

    private var day: Int { Calendar.current.component(.day, from: date) }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    var body: some View {
        ZStack {
            Circle()
                .fill(hasRide ? Color.green : Color(.systemGray5))
            Text("\(day)")
                .font(.system(size: 10, weight: isToday ? .black : .regular))
                .foregroundStyle(hasRide ? .white : .primary)
                .minimumScaleFactor(0.5)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    YearlyKmWidget()
} timeline: {
    BikeWidgetTimelineEntry(date: .now, yearlyKm: 342.5, rideDays: [], allEntries: [])
}

#Preview("Medium", as: .systemMedium) {
    YearlyKmCalendarWidget()
} timeline: {
    BikeWidgetTimelineEntry(
        date: .now,
        yearlyKm: 1287.3,
        rideDays: [
            Calendar.current.dateComponents([.year, .month, .day], from: .now),
            Calendar.current.dateComponents([.year, .month, .day], from: Calendar.current.date(byAdding: .day, value: -2, to: .now)!),
            Calendar.current.dateComponents([.year, .month, .day], from: Calendar.current.date(byAdding: .day, value: -5, to: .now)!)
        ],
        allEntries: []
    )
}
