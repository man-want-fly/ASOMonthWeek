//
//  MonthPlanViewDelegate.swift
//  CalLib
//
//  Created by mwf on 2023/8/13.
//

import UIKit

public protocol MonthPlanViewDelegate: AnyObject {

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        attributedStringForDayHeaderAt date: Date
    ) -> NSAttributedString?
    
    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didDisplayMonthAt date: Date
    )

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
        date: Date,
        completion: (() -> Void)?
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
