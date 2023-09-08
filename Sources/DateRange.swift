//
//  DateRange.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import Foundation
import UIKit

class DateRange: NSObject, NSCopying {

    var start: Date
    var end: Date

    var isEmpty: Bool { start == end }

    class func dateRange(start: Date, end: Date) -> DateRange {
        .init(start: start, end: end)
    }

    init(start: Date, end: Date) {
        self.start = start
        self.end = end

        super.init()

        checkIfValid()
    }

    func isEqual(to dateRange: DateRange) -> Bool {
        dateRange.start == start && dateRange.end == end
    }

    func components(unitFlags: Set<Calendar.Component>, for calendar: Calendar) -> DateComponents {
        checkIfValid()
        return calendar.dateComponents(unitFlags, from: start, to: end)
    }

    func contains(_ date: Date) -> Bool {
        checkIfValid()
        return (start...end).contains(date)
    }

    func intersect(_ dateRange: DateRange) {
        checkIfValid()

        // Check for no intersection
        if dateRange.end <= start || end <= dateRange.start {
            end = start
            return
        }

        // Update start if necessary
        if start < dateRange.start {
            start = dateRange.start
        }

        // Update end if necessary
        if dateRange.end < end {
            end = dateRange.end
        }
    }

    func intersects(_ dateRange: DateRange) -> Bool {
        (start...end).overlaps(dateRange.start...dateRange.end)
    }

    func includes(_ dateRange: DateRange) -> Bool {
        start <= dateRange.start && end >= dateRange.end
    }

    func union(_ dateRange: DateRange) {
        checkIfValid()
        dateRange.checkIfValid()

        start = min(start, dateRange.start)
        end = max(end, dateRange.end)
    }

    func enumerateDays(with calendar: Calendar, using block: (Date, inout Bool) -> Void) {
        var comp = DateComponents()
        comp.day = 1

        var date = start
        var stop = false

        while !stop && date.compare(end) == .orderedAscending {
            block(date, &stop)
            date = calendar.date(byAdding: comp, to: start)!
            comp.day! += 1
        }
    }

    func copy(with zone: NSZone? = nil) -> Any {
        DateRange(start: start, end: end)
    }

    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? DateRange else { return false }

        //        if self == object {
        //            return true
        //        }

        return isEqual(to: object)
    }

    override var hash: Int {
        start.hashValue ^ end.hashValue
    }

    override var description: String {
        return """
                start: \(start)
                end: \(end)
            """
    }

    private func checkIfValid() {
        assert(
            start.compare(end) != .orderedDescending,
            "End date earlier than start date in DateRange object!"
        )
    }
}
