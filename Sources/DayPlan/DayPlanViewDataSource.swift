//
//  DayPlanViewDataSource.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import UIKit

public enum DayPlanTimeMark: Int {
    case header = 0
    case current, floating
}

public enum DayPlanScrollType: Int {
    case dateTime = 0
    case date, time
}

public enum DayPlanCoveringType: Int {
    case classic = 0, complex
}

// MARK: - DayPlanViewDataSource
public protocol DayPlanViewDataSource: AnyObject {

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        numberOfEventsOfType eventType: EventType,
        at date: Date
    ) -> Int

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        viewForEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> EventView?

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        dateRangeForEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> DateRange?

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        shouldStartMovingEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> Bool

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        canMoveEventOfType eventType: EventType,
        at index: Int,
        date: Date,
        toType targetType: EventType,
        toDate targetDate: Date
    ) -> Bool

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        moveEventOfType eventType: EventType,
        at index: Int,
        date: Date,
        toType targetType: EventType,
        toDate targetDate: Date
    )

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        viewForNewEventOfType eventType: EventType,
        at date: Date
    ) -> EventView?

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        canCreateNewEventOfType eventType: EventType,
        at date: Date
    ) -> Bool

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        createNewEventOfType eventType: EventType,
        at date: Date
    )
}

// MARK: - DayPlanViewDelegate
public protocol DayPlanViewDelegate: AnyObject {

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        attributedStringForTimeMark timeMark: DayPlanTimeMark,
        time: TimeInterval
    ) -> NSAttributedString?

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        attributedStringForDayHeaderAt date: Date
    ) -> NSAttributedString?

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        numberOfDimmedTimeRangesAt date: Date
    ) -> Int

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        dimmedTimeRangeAt index: Int,
        date: Date
    ) -> DateRange?

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didScroll scrollType: DayPlanScrollType
    )

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didEndScrolling scrollType: DayPlanScrollType
    )

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        willDisplay date: Date
    )

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didEndDisplaying date: Date
    )

    func dayPlanViewDidZoom(
        _ dayPlanView: DayPlanView
    )

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        shouldSelectEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> Bool

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didSelectEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> Bool

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didDeselectEventOfType eventType: EventType,
        at index: Int,
        date: Date
    )
}
