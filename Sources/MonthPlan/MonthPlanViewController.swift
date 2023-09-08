//
//  MonthPlanViewController.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import UIKit

class MonthPlanViewController: UIViewController, MonthPlanViewDataSource, MonthPlanViewDelegate {
    
    var monthPlanView: MonthPlanView = .init(frame: .zero) {
        didSet {
            monthPlanView.dataSource = self
            monthPlanView.delegate = self
        }
    }
        
    override func loadView() {
//        super.loadView()

        monthPlanView = .init(frame: .zero)
        monthPlanView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view = monthPlanView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        monthPlanView.dataSource = self
        monthPlanView.delegate = self
    }
    
    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        numberOfEventsAt date: Date
    ) -> Int {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        dateRangeForEventAt index: Int,
        date: Date
    ) -> DateRange {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        cellForEventAt index: Int,
        date: Date
    ) -> EventView {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        cellForNewEventAt date: Date
    ) -> EventView {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        canMoveCellForEventAt index: Int,
        date: Date
    ) -> Bool {
        fatalError("must subclass")
    }
    
    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        attributedStringForDayHeaderAt date: Date
    ) -> NSAttributedString? {
        fatalError("must subclass")
    }

    func monthPlanViewDidScroll(_ monthPlanView: MonthPlanView) {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didSelectDayCellAt date: Date
    ) {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didShow cell: EventView,
        forNewEventAt date: Date
    ) {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        willStartMovingEventAt index: Int,
        date: Date
    ) {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didMoveEventAt index: Int,
        fromDate: Date,
        toDate: Date
    ) {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        shouldSelectEventAt index: Int,
        date: Date
    ) -> Bool {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didSelectEventAt index: Int,
        date: Date
    ) {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        shouldDeselectEventAt index: Int,
        date: Date
    ) -> Bool {
        fatalError("must subclass")
    }

    func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didDeselectEventAt index: Int,
        date: Date
    ) {
        fatalError("must subclass")
    }
}
