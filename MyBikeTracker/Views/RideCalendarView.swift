//
//  RideCalendarView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 05.03.2025.
//

import SwiftUI

struct RideCalendarView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    private var rides: [Ride] { ridesViewModel.rides }

    @State private var displayedMonth: Date = Date().startOfMonth
    @State private var showsYearView = false

    private let calendar = Calendar.current

    private var ridesByDay: [DateComponents: [Ride]] {
        Dictionary(grouping: rides) {
            calendar.dateComponents([.year, .month, .day], from: $0.startDate)
        }
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    var body: some View {
        Group {
            if showsYearView {
                yearView
            } else {
                monthView
            }
        }
        .navigationTitle(LocalizedStringKey("calendar_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showsYearView.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(headerTitle)
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(showsYearView ? 180 : 0))
                    }
                    .foregroundStyle(.primary)
                }
                .accessibilityLabel(LocalizedStringKey("calendar_toggle_year"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(LocalizedStringKey("calendar_today")) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        displayedMonth = Date().startOfMonth
                        showsYearView = false
                    }
                }
                .disabled(calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month) && !showsYearView)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: displayedMonth)
        .animation(.easeInOut(duration: 0.25), value: showsYearView)
    }

    // MARK: - Month

    private var monthView: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)

            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 8) {
                ForEach(CalendarGrid.days(for: displayedMonth, calendar: calendar)) { day in
                    NavigationLink {
                        RideDayDetailView(date: day.date, rides: rides(on: day.date), ridesViewModel: ridesViewModel)
                    } label: {
                        MonthDayCell(
                            date: day.date,
                            isInDisplayedMonth: day.isInDisplayedMonth,
                            hasRide: hasRide(on: day.date),
                            isToday: calendar.isDateInToday(day.date)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .gesture(monthSwipeGesture)

            Spacer()
        }
        .padding(.top, 8)
        .brandScreen()
    }

    // MARK: - Year

    private var yearView: some View {
        ScrollView {
            HStack {
                Button {
                    changeYear(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                Button {
                    changeYear(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 20) {
                ForEach(monthsInDisplayedYear, id: \.self) { month in
                    MiniMonthView(
                        month: month,
                        weekdaySymbols: weekdaySymbols,
                        ridesByDay: ridesByDay,
                        ridesViewModel: ridesViewModel
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            displayedMonth = month.startOfMonth
                            showsYearView = false
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .brandScreen()
    }

    // MARK: - Shared

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 12)
    }

    private var headerTitle: String {
        if showsYearView {
            return displayedMonth.formatted(.dateTime.year())
        }
        return displayedMonth.formatted(.dateTime.month(.wide).year()).capitalized
    }

    private var monthsInDisplayedYear: [Date] {
        let year = calendar.component(.year, from: displayedMonth)
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                changeMonth(by: value.translation.width < 0 ? 1 : -1)
            }
    }

    private func rides(on date: Date) -> [Ride] {
        ridesByDay[calendar.dateComponents([.year, .month, .day], from: date)] ?? []
    }

    private func hasRide(on date: Date) -> Bool {
        ridesByDay[calendar.dateComponents([.year, .month, .day], from: date)] != nil
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth.startOfMonth
        }
    }

    private func changeYear(by value: Int) {
        if let newMonth = calendar.date(byAdding: .year, value: value, to: displayedMonth) {
            displayedMonth = newMonth.startOfMonth
        }
    }
}

// MARK: - Month day cell

private struct MonthDayCell: View {
    let date: Date
    let isInDisplayedMonth: Bool
    let hasRide: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(date, format: .dateTime.day())
                .font(.body.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Color.white : Brand.Color.ink)
                .frame(width: 36, height: 36)
                .background {
                    if isToday {
                        Circle().fill(Brand.Color.ember.gradient)
                    }
                }

            Circle()
                .fill(hasRide ? Brand.Color.trail : Color.clear)
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .opacity(isInDisplayedMonth ? 1 : 0.28)
        .contentShape(Rectangle())
    }
}

// MARK: - Mini month (year)

private struct MiniMonthView: View {
    let month: Date
    let weekdaySymbols: [String]
    let ridesByDay: [DateComponents: [Ride]]
    @ObservedObject var ridesViewModel: RidesViewModel
    let onSelectMonth: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onSelectMonth) {
                Text(month.formatted(.dateTime.month(.wide)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Brand.Color.trail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)

            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                ForEach(CalendarGrid.days(for: month, calendar: calendar)) { day in
                    if day.isInDisplayedMonth {
                        NavigationLink {
                            RideDayDetailView(date: day.date, rides: rides(on: day.date), ridesViewModel: ridesViewModel)
                        } label: {
                            miniDayLabel(day)
                        }
                        .buttonStyle(.plain)
                    } else {
                        miniDayLabel(day)
                            .opacity(0)
                    }
                }
            }
        }
        .padding(8)
    }

    private func miniDayLabel(_ day: CalendarGridDay) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        return Text(day.date, format: .dateTime.day())
            .font(.system(size: 10, weight: isToday ? .bold : .regular))
            .foregroundStyle(isToday ? Color.white : Brand.Color.ink)
            .frame(maxWidth: .infinity, minHeight: 14)
            .background {
                if isToday {
                    Circle().fill(Brand.Color.ember.gradient)
                }
            }
    }

    private func rides(on date: Date) -> [Ride] {
        ridesByDay[calendar.dateComponents([.year, .month, .day], from: date)] ?? []
    }
}

// MARK: - Grid helpers

struct CalendarGridDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    var id: Date { date }
}

enum CalendarGrid {
    static func days(for month: Date, calendar: Calendar) -> [CalendarGridDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7

        var days: [CalendarGridDay] = []
        if leading > 0, let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthInterval.start) {
            for offset in 0..<leading {
                if let date = calendar.date(byAdding: .day, value: offset, to: gridStart) {
                    days.append(CalendarGridDay(date: date, isInDisplayedMonth: false))
                }
            }
        }

        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(CalendarGridDay(date: date, isInDisplayedMonth: true))
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        }

        while days.count % 7 != 0 {
            days.append(CalendarGridDay(date: date, isInDisplayedMonth: false))
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        }
        return days
    }
}

extension Date {
    var startOfMonth: Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: comps) ?? self
    }
}
