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
