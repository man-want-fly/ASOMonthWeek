//
//  DayPlanViewController.swift
//  CalLib
//
//  Created by mwf on 2023/8/23.
//

import UIKit

class DayPlanViewController: UIViewController, DayPlanViewDataSource, DayPlanViewDelegate {

    var dayPlanView: DayPlanView {
        set {
            super.view = newValue
            newValue.dataSource = self
            newValue.delegate = self
        }
        get {
            view as! DayPlanView
        }
    }

    var headerView: CalendarHeaderView?

    var showsWeekHeaderView: Bool = false

    private var firstVisibleDayForRotation: Date?

    override func loadView() {

        let dayPlanView = DayPlanView()
        dayPlanView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        self.dayPlanView = dayPlanView
        self.dayPlanView.autoresizesSubviews = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard headerView == nil, showsWeekHeaderView else { return }
        dayPlanView.numberOfVisibleDays = 1
        dayPlanView.dayHeaderHeight = 90
        dayPlanView.visibleDays.start = Date()

        setupHeaderView()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(
            alongsideTransition: nil,
            completion: { context in
                if let view = self.headerView {
                    //force to scroll to a correct position after rotation
                    view.didMoveToSuperview()
                }
            }
        )
    }

    private func setupHeaderView() {
        let headerView = CalendarHeaderView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: dayPlanView.frame.size.width,
                height: dayPlanView.dayHeaderHeight
            ),
            collectionViewLayout: UICollectionViewFlowLayout(),
            dayPlannerView: dayPlanView
        )

        headerView.autoresizingMask = [.flexibleWidth]
        view.addSubview(headerView)

        self.headerView = headerView
    }

    // MARK: - DayPlanViewDataSource
    func dayPlanView(
        _ dayPlanView: DayPlanView,
        numberOfEventsOfType eventType: EventType,
        at date: Date
    ) -> Int {
        0
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        viewForEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> EventView? {
        nil
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        dateRangeForEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> DateRange? {
        nil
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        shouldStartMovingEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> Bool {
        false
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        canMoveEventOfType eventType: EventType,
        at index: Int,
        date: Date,
        toType targetType: EventType,
        toDate targetDate: Date
    ) -> Bool {
        false
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        moveEventOfType eventType: EventType,
        at index: Int,
        date: Date,
        toType targetType: EventType,
        toDate targetDate: Date
    ) {}

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        viewForNewEventOfType eventType: EventType,
        at date: Date
    ) -> EventView? {
        nil
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        canCreateNewEventOfType eventType: EventType,
        at date: Date
    ) -> Bool {
        true
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        createNewEventOfType eventType: EventType,
        at date: Date
    ) {}

    // MARK: - DayPlanViewDelegate
    func dayPlanView(
        _ dayPlanView: DayPlanView,
        attributedStringForTimeMark timeMark: DayPlanTimeMark,
        time: TimeInterval
    ) -> NSAttributedString? {
        nil
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        attributedStringForDayHeaderAt date: Date
    ) -> NSAttributedString? {
        nil
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        numberOfDimmedTimeRangesAt date: Date
    ) -> Int {
        0
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        dimmedTimeRangeAt index: Int,
        date: Date
    ) -> DateRange? {
        nil
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didScroll scrollType: DayPlanScrollType
    ) {}

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didEndScrolling scrollType: DayPlanScrollType
    ) {
        headerView?.select(date: dayPlanView.visibleDays.start)
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        willDisplay date: Date
    ) {}

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didEndDisplaying date: Date
    ) {}

    func dayPlanViewDidZoom(
        _ dayPlanView: DayPlanView
    ) {}

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        shouldSelectEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> Bool {
        false
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didSelectEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> Bool {
        false
    }

    func dayPlanView(
        _ dayPlanView: DayPlanView,
        didDeselectEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) {}
}
