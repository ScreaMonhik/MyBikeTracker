//
//  RideCalendarView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 05.03.2025.
//

import SwiftUI

struct RideCalendarView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rides: [Ride] { ridesViewModel.rides }
    private let calendar = Calendar.current

    @State private var visibleMonth: CalendarMonth?
    @State private var visibleYear: Int?
    @State private var showsYearView = false

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

    private var monthSpan: [CalendarMonth] {
        CalendarMonth.sequence(from: spanStart, through: spanEnd)
    }

    private var years: [Int] {
        Array(spanStart.year...spanEnd.year)
    }

    private var spanStart: CalendarMonth {
        let today = CalendarMonth.from(Date(), calendar: calendar).adding(months: -36)
        guard let firstRide = rides.map(\.startDate).min() else { return today }
        let rideStart = CalendarMonth.from(firstRide, calendar: calendar).adding(months: -12)
        return min(today, rideStart)
    }

    private var spanEnd: CalendarMonth {
        let today = CalendarMonth.from(Date(), calendar: calendar).adding(months: 18)
        guard let lastRide = rides.map(\.startDate).max() else { return today }
        let rideEnd = CalendarMonth.from(lastRide, calendar: calendar).adding(months: 12)
        return max(today, rideEnd)
    }

    private var selectedMonth: CalendarMonth {
        visibleMonth ?? CalendarMonth.from(Date(), calendar: calendar)
    }

    var body: some View {
        Group {
            if showsYearView {
                yearView
            } else {
                monthPager
            }
        }
        .navigationTitle(LocalizedStringKey("calendar_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: toggleYearView) {
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
                Button(LocalizedStringKey("calendar_today"), action: jumpToToday)
                    .disabled(isShowingToday)
            }
        }
        .animation(Brand.Motion.snappy(reduceMotion: reduceMotion), value: showsYearView)
        .sensoryFeedback(.selection, trigger: visibleMonth)
        .onAppear {
            if visibleMonth == nil {
                visibleMonth = CalendarMonth.from(Date(), calendar: calendar)
            }
        }
    }

    // MARK: - Month pager

    private var monthPager: some View {
        VStack(spacing: 12) {
            weekdayHeader

            TabView(selection: monthSelection) {
                ForEach(monthSpan) { month in
                    monthPage(for: month)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .tag(month)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(.top, 8)
        .brandScreen()
    }

    private var monthSelection: Binding<CalendarMonth> {
        Binding(
            get: { selectedMonth },
            set: { visibleMonth = $0 }
        )
    }

    private func monthPage(for month: CalendarMonth) -> some View {
        let monthDate = month.date(in: calendar)
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 8
        ) {
            ForEach(CalendarGrid.days(for: monthDate, calendar: calendar, minimumRows: 6)) { day in
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(monthDate.formatted(.dateTime.month(.wide).year()))
    }

    // MARK: - Year ribbon

    private var yearView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    ForEach(years, id: \.self) { year in
                        yearSection(year)
                            .id(year)
                    }
                }
                .scrollTargetLayout()
                .padding(.bottom, 48)
            }
            .scrollPosition(id: $visibleYear, anchor: .top)
            .brandScreen()
            .onAppear {
                let year = selectedMonth.year
                visibleYear = year
                proxy.scrollTo(year, anchor: .top)
            }
        }
    }

    private func yearSection(_ year: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(year))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.Color.ink)
                .padding(.horizontal, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3),
                spacing: 20
            ) {
                ForEach(CalendarMonth.months(in: year)) { month in
                    MiniMonthView(
                        month: month.date(in: calendar),
                        ridesByDay: ridesByDay,
                        ridesViewModel: ridesViewModel,
                        isCurrentMonth: month == CalendarMonth.from(Date(), calendar: calendar)
                    ) {
                        openMonth(month)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
            return String(visibleYear ?? selectedMonth.year)
        }
        return selectedMonth.date(in: calendar)
            .formatted(.dateTime.month(.wide).year())
            .capitalized
    }

    private var isShowingToday: Bool {
        !showsYearView && selectedMonth == CalendarMonth.from(Date(), calendar: calendar)
    }

    private func rides(on date: Date) -> [Ride] {
        ridesByDay[calendar.dateComponents([.year, .month, .day], from: date)] ?? []
    }

    private func hasRide(on date: Date) -> Bool {
        ridesByDay[calendar.dateComponents([.year, .month, .day], from: date)] != nil
    }

    private func toggleYearView() {
        if showsYearView {
            showsYearView = false
        } else {
            visibleYear = selectedMonth.year
            showsYearView = true
        }
    }

    private func openMonth(_ month: CalendarMonth) {
        visibleMonth = month
        showsYearView = false
    }

    private func jumpToToday() {
        let today = CalendarMonth.from(Date(), calendar: calendar)
        visibleMonth = today
        visibleYear = today.year
        showsYearView = false
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
    let ridesByDay: [DateComponents: [Ride]]
    @ObservedObject var ridesViewModel: RidesViewModel
    let isCurrentMonth: Bool
    let onSelectMonth: () -> Void

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: onSelectMonth) {
                Text(month.formatted(.dateTime.month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isCurrentMonth ? Brand.Color.ember : Brand.Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)

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
    }

    private func miniDayLabel(_ day: CalendarGridDay) -> some View {
        let isToday = calendar.isDateInToday(day.date)
        let hasRide = rides(on: day.date) != []
        return Text(day.date, format: .dateTime.day())
            .font(.system(size: 10, weight: isToday ? .bold : .regular))
            .foregroundStyle(isToday ? Color.white : hasRide ? Brand.Color.trail : Brand.Color.ink)
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

// MARK: - Month identity

struct CalendarMonth: Hashable, Comparable, Identifiable {
    let year: Int
    let month: Int

    var id: Self { self }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }

    func date(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    static func from(_ date: Date, calendar: Calendar) -> CalendarMonth {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return CalendarMonth(year: comps.year ?? 2000, month: comps.month ?? 1)
    }

    func adding(months value: Int) -> CalendarMonth {
        var nextYear = year
        var nextMonth = month + value
        while nextMonth > 12 {
            nextMonth -= 12
            nextYear += 1
        }
        while nextMonth < 1 {
            nextMonth += 12
            nextYear -= 1
        }
        return CalendarMonth(year: nextYear, month: nextMonth)
    }

    static func months(in year: Int) -> [CalendarMonth] {
        (1...12).map { CalendarMonth(year: year, month: $0) }
    }

    static func sequence(from start: CalendarMonth, through end: CalendarMonth) -> [CalendarMonth] {
        guard start <= end else { return [] }
        var months: [CalendarMonth] = []
        var current = start
        while current <= end {
            months.append(current)
            current = current.adding(months: 1)
        }
        return months
    }
}

// MARK: - Grid helpers

struct CalendarGridDay: Identifiable {
    let date: Date
    let isInDisplayedMonth: Bool
    var id: Date { date }
}

enum CalendarGrid {
    static func days(for month: Date, calendar: Calendar, minimumRows: Int = 0) -> [CalendarGridDay] {
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

        let minimumCount = minimumRows * 7
        while days.count < minimumCount || days.count % 7 != 0 {
            days.append(CalendarGridDay(date: date, isInDisplayedMonth: false))
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)
        }
        return days
    }
}
