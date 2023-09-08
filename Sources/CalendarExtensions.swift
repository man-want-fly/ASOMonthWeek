//
//  CalendarExtensions.swift
//  CalLib
//
//  Created by mwf on 2023/8/13.
//

import Foundation

extension Calendar {
    
    func startDayOfStartWeek(for date: Date) -> Date {
        startOfWeek(for: startOfMonth(for: date))
    }
    
    func endDayOfEndWeek(for date: Date) -> Date {
        nextStartOfWeek(for: nextStartOfDay(for: date))
    }

    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
        
//        let components = dateComponents([.year, .month], from: date)
//        let firstWeek = self.date(from: components)!
//        return startOfWeek(for: firstWeek)
    }

    func nextStartOfMonth(for date: Date) -> Date {
        //        date.dateAt(.nextMonth)
        let firstDay = startOfMonth(for: date)
        let comps = DateComponents(month: 1)
        return self.date(byAdding: comps, to: firstDay)!
    }

    func startOfWeek(for date: Date) -> Date {
        //        date.dateAtStartOf(.weekOfMonth)
        let components = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }

    func nextStartOfWeek(for date: Date) -> Date {
        //        let next = self.date(byAdding: .weekdayOrdinal, value: 1, to: date)!
        let next = self.date(byAdding: .day, value: 7, to: date)!
        return startOfWeek(for: next)
    }

    func nextStartOfDay(for date: Date) -> Date {
        //        date.dateAt(.tomorrowAtStart)
        let next = self.date(byAdding: .day, value: 1, to: date)!
        return startOfDay(for: next)
    }

    func indexOfWeekInMonth(for date: Date) -> Int {
        var index = ordinality(of: .weekOfMonth, in: .month, for: date)!

        let startOfMonth = startOfMonth(for: date)
        let firstWeekRange = range(of: .day, in: .weekOfMonth, for: startOfMonth)!

        if firstWeekRange.count < minimumDaysInFirstWeek {
            index += 1
        }

        return index
    }

    func isDate(_ date1: Date, sameDayAs date2: Date) -> Bool {
        startOfDay(for: date1) == startOfDay(for: date2)
    }

    func isDate(_ date1: Date, sameMonthAs date2: Date) -> Bool {
        isDate(date1, equalTo: date2, toGranularity: .month)
    }

    func firstDayOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
    
    func lastDayOfMonth(for date: Date) -> Date {
        self.date(byAdding: DateComponents(month: 1, day: -1), to: date)!
    }

    func firstDayOfWeekInMonth(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps)!
    }

    func firstDayOfFirstWeekInMonth(for date: Date) -> Date {
        let startOfDay = firstDayOfMonth(for: date)
        return firstDayOfWeekInMonth(for: startOfDay)
    }

    func lastDayOfWeekInMonth(for date: Date) -> Date {
        self.date(
            byAdding: DateComponents(day: 6),
            to: firstDayOfWeekInMonth(for: date)
        )!
    }

    func lastDayOfLastWeekOfMonth(for date: Date) -> Date {
        let lastDay = lastDayOfMonth(for: date)
        return lastDayOfWeekInMonth(for: lastDay)
    }
}
