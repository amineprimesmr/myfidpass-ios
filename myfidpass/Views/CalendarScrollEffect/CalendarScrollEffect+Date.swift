//
//  CalendarScrollEffect+Date.swift
//  myfidpass
//
//  Intégré depuis CalendarScrollEffect/Extensions/Date+Extensions.swift
//

import SwiftUI

extension Date {
    /// Les 7 jours de la semaine courante (intervalle `weekOfYear`, cohérent avec le calendrier utilisateur).
    static var calendarScrollCurrentWeek: [CalendarScrollDay] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        var week: [CalendarScrollDay] = []
        var d = interval.start
        for _ in 0..<7 {
            week.append(CalendarScrollDay(date: d))
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return week
    }

    /// Convert date to string in the given format
    func calendarScrollString(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format

        return formatter.string(from: self)
    }

    /// Check if both the dates are same
    func calendarScrollIsSame(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(self, inSameDayAs: date)
    }
}

/// Jour affiché dans le calendrier défilant : identifiant stable (pas d’UUID) pour `scrollPosition` / `ForEach`.
struct CalendarScrollDay: Identifiable, Hashable {
    var date: Date

    var id: String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(Calendar.current.startOfDay(for: date))
    }

    static func == (lhs: CalendarScrollDay, rhs: CalendarScrollDay) -> Bool {
        Calendar.current.isDate(lhs.date, inSameDayAs: rhs.date)
    }
}
