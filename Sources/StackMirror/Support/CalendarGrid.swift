import Foundation

/// Month layout and day grouping for the calendar, kept free of SwiftUI so it can be tested.
struct CalendarGrid: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func startOfMonth(containing date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    func month(offsetBy months: Int, from date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: startOfMonth(containing: date))!
    }

    /// Whole weeks covering the month. `nil` cells pad the first and last week.
    func cells(forMonthContaining date: Date) -> [Date?] {
        let first = startOfMonth(containing: date)
        let dayCount = calendar.range(of: .day, in: .month, for: first)!.count
        let leading = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        let days: [Date?] = (0..<dayCount).map { calendar.date(byAdding: .day, value: $0, to: first) }
        let trailing = (7 - (leading + dayCount) % 7) % 7
        return Array(repeating: nil, count: leading) + days + Array(repeating: nil, count: trailing)
    }

    /// Weekday symbols ordered to match `cells`, honoring the locale's first weekday.
    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Scheduled drafts keyed by the start of their local day, each day sorted by time.
    func draftsByDay(_ drafts: [SubstackDraft]) -> [Date: [SubstackDraft]] {
        Dictionary(grouping: drafts.filter { $0.triggerAt != nil }) {
            calendar.startOfDay(for: $0.triggerAt!)
        }
        .mapValues { $0.sorted { $0.triggerAt! < $1.triggerAt! } }
    }
}
