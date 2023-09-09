//
//  DateRange.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import Foundation
import UIKit

public class DateRange: NSObject, NSCopying {

    public var start: Date
    public var end: Date

    public var isEmpty: Bool { start == end }

    public class func dateRange(start: Date, end: Date) -> DateRange {
        .init(start: start, end: end)
    }

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end

        super.init()

        checkIfValid()
    }

    public func isEqual(to dateRange: DateRange) -> Bool {
        dateRange.start == start && dateRange.end == end
    }

    public func components(unitFlags: Set<Calendar.Component>, for calendar: Calendar) -> DateComponents {
        checkIfValid()
        return calendar.dateComponents(unitFlags, from: start, to: end)
    }

    public func contains(_ date: Date) -> Bool {
        checkIfValid()
        return (start...end).contains(date)
    }

    public func intersect(_ dateRange: DateRange) {
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

    public func intersects(_ dateRange: DateRange) -> Bool {
        (start...end).overlaps(dateRange.start...dateRange.end)
    }

    public func includes(_ dateRange: DateRange) -> Bool {
        start <= dateRange.start && end >= dateRange.end
    }

    public func union(_ dateRange: DateRange) {
        checkIfValid()
        dateRange.checkIfValid()

        start = min(start, dateRange.start)
        end = max(end, dateRange.end)
    }

    public func enumerateDays(with calendar: Calendar, using block: (Date, inout Bool) -> Void) {
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

    public func copy(with zone: NSZone? = nil) -> Any {
        DateRange(start: start, end: end)
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? DateRange else { return false }

        //        if self == object {
        //            return true
        //        }

        return isEqual(to: object)
    }

    public override var hash: Int {
        start.hashValue ^ end.hashValue
    }

    public override var description: String {
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
