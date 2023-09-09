//
//  MonthPlanViewDataSource.swift
//  CalLib
//
//  Created by mwf on 2023/8/13.
//

import UIKit

public protocol MonthPlanViewDataSource: AnyObject {

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        numberOfEventsAt date: Date
    ) -> Int

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        dateRangeForEventAt index: Int,
        date: Date
    ) -> DateRange

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        cellForEventAt index: Int,
        date: Date
    ) -> EventView

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        cellForNewEventAt date: Date
    ) -> EventView

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        canMoveCellForEventAt index: Int,
        date: Date
    ) -> Bool
}

//extension MonthPlanViewDataSource {
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        cellForNewEventAt date: Date
//    ) -> EventView {
//        StandardEventView()
//    }
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        canMoveCellForEventAt index: Int,
//        date: Date
//    ) -> Bool {
//        true
//    }
//}

public protocol MonthPlanViewDelegate: AnyObject {

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        attributedStringForDayHeaderAt date: Date
    ) -> NSAttributedString?

    func monthPlanViewDidScroll(_ monthPlanView: MonthPlanView)

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didSelectDayCellAt date: Date
    )

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didShow cell: EventView,
        forNewEventAt date: Date
    )

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        willStartMovingEventAt index: Int,
        date: Date
    )

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didMoveEventAt index: Int,
        fromDate: Date,
        toDate: Date
    )

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        shouldSelectEventAt index: Int,
        date: Date
    ) -> Bool

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didSelectEventAt index: Int,
        date: Date
    )

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        shouldDeselectEventAt index: Int,
        date: Date
    ) -> Bool

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didDeselectEventAt index: Int,
        date: Date
    )
}
//extension MonthPlanViewDelegate {
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        attributedStringForDayHeaderAt date: Date
//    ) -> NSAttributedString {
//        return .init(string: "haha- def")
//    }
//
//    func monthPlanViewDidScroll(_ monthPlanView: MonthPlanView) {
//        
//    }
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        didSelectDayCellAt date: Date
//    ) {}
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        didShow cell: EventView,
//        forNewEventAt date: Date
//    ) {}
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        willStartMovingEventAt index: Int,
//        date: Date
//    ) {}
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        didMoveEventAt index: Int,
//        fromDate: Date,
//        toDate: Date
//    ) {}
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        shouldSelectEventAt index: Int,
//        date: Date
//    ) -> Bool {
//        false
//    }
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        didSelectEventAt index: Int,
//        date: Date
//    ) {}
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        shouldDeselectEventAt index: Int,
//        date: Date
//    ) -> Bool {
//        false
//    }
//
//    func monthPlanView(
//        _ monthPlanView: MonthPlanView,
//        didDeselectEventAt index: Int,
//        date: Date
//    ) {}
//}
