//
//  MonthPlanEKViewController.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import Cache
import Collections
import EventKit
import OrderedCollections
import UIKit

open class MonthPlanEKViewController: MonthPlanViewController {

    public var calendar: Calendar = .current {
        didSet {
            dateFormatter.calendar = calendar
            monthPlanView.calendar = calendar
        }
    }

    var visibleCalendars: [EKCalendar] = [] {
        didSet {
            monthPlanView.reloadEvents()
        }
    }

    private let eventKitSupport: EventKitSupport

    private let bgQueue: DispatchQueue = DispatchQueue(label: "MonthPlanEKViewController.bgQueue")

    private let cachedMonths: MemoryStorage<Date, [Date: [EKEvent]]> = MemoryStorage(
        config: .init(
            expiry: .never,
            countLimit: 500,
            totalCostLimit: 10 * 1024 * 1024
        )
    )

    private var datesForMonthsToLoad: OrderedSet<Date>?

    private var visibleMonths: DateRange?
    private var movedEvent: EKEvent?
    private lazy var dateFormatter = DateFormatter()

    let eventStore: EKEventStore

    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
        self.eventKitSupport = .init(eventStore: eventStore)
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadEvents),
            name: .EKEventStoreChanged,
            object: eventStore
        )

        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short

        eventKitSupport.checkEventStoreAccess { granted in
            if granted {
                let calendars = self.eventStore.calendars(for: .event)
                self.visibleCalendars = calendars
                self.reloadEvents()
            }
        }

        monthPlanView.calendar = calendar
        monthPlanView.register(
            cellClass: MonthStandardEventView.self,
            forEventCellWithReuseIdentifier: ReusableConstants.Identifier.eventCell
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        loadEventsIfNeeded()
    }

    @objc func reloadEvents() {
        cachedMonths.removeAll()
        loadEventsIfNeeded()
    }

    private func events(at date: Date) -> [EKEvent] {
        let firstOfMonth = calendar.startOfMonth(for: date)

        do {
            let days = try cachedMonths.object(forKey: firstOfMonth)
            let events =
                days[date]?
                .filter { event in
                    visibleCalendars.contains(event.calendar)
                } ?? []
            return events
        } catch {
            return []
        }
    }

    private func event(at index: Int, date: Date) -> EKEvent {
        let events = events(at: date)
        return events[index]
    }

    private func visibleMonthsRange() -> DateRange? {
        guard let visibleDaysRange = monthPlanView.visibleDays() else { return nil }
        let start = calendar.startOfMonth(for: visibleDaysRange.start)
        let end = calendar.nextStartOfMonth(for: visibleDaysRange.end)
        return DateRange(start: start, end: end)
    }

    private func fetchEvents(
        from startDate: Date,
        to endDate: Date,
        calendars: [EKCalendar]?
    ) -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: calendars
        )

        if eventKitSupport.accessGranted {
            return
                eventStore
                .events(matching: predicate)
                .sorted { $0.compareStartDate(with: $1) == .orderedAscending }
        }

        return []
    }

    private func allEvents(in range: DateRange) -> [Date: [EKEvent]] {
        let events = fetchEvents(from: range.start, to: range.end, calendars: nil)

        var eventsPerDay: [Date: [EKEvent]] = [:]

        for event in events {
            let start = calendar.startOfDay(for: event.startDate)
            let eventRange = DateRange(start: start, end: event.endDate)
            eventRange.intersect(range)

            eventRange.enumerateDays(with: calendar) { (date, stop) in
                var events = eventsPerDay[date] ?? [EKEvent]()
                events.append(event)
                eventsPerDay[date] = events
            }
        }

        return eventsPerDay
    }

    private func bg_loadMonthStarting(at date: Date) {
        let end = calendar.nextStartOfMonth(for: date)
        let range = DateRange(start: date, end: end)

        let dic = allEvents(in: range)

        //        print("bg_loadMonthStartingAtDate: \(date)")
        //        print("bg_loadMonthStartingAtDate dic: \(dic)")

        DispatchQueue.main.async {
            //            print("cachedMonths setObject dic: \(dic)")
            self.cachedMonths.setObject(dic, forKey: date)
            //self.datesForMonthsToLoad.removeObject(date)

            let rangeEnd = self.calendar.nextStartOfMonth(for: date)
            let range = DateRange(start: date, end: rangeEnd)
            self.monthPlanView.reloadEvents(in: range)

            //self.cacheEvents(dic, forMonthStartingAt: date)
        }
    }

    private func bg_loadOneMonth() {
        var date: Date?

        DispatchQueue.main.sync { [weak self] in
            guard let self else { return }

            date = datesForMonthsToLoad?.first

            if let date, let index = datesForMonthsToLoad?.firstIndex(of: date) {
                datesForMonthsToLoad?.remove(at: index)
            }

            if let visibleDays = monthPlanView.visibleDays(),
                let visibleMonths,
                !visibleDays.intersects(visibleMonths)
            {
                date = nil
            }
        }

        if let date {
            bg_loadMonthStarting(at: date)
        }
    }

    private func addMonthToLoadingQueue(monthStart: Date) {
        if datesForMonthsToLoad == nil {
            datesForMonthsToLoad = .init()
        }

        datesForMonthsToLoad?.append(monthStart)

        bgQueue.async(execute: bg_loadOneMonth)
    }

    private func loadEventsIfNeeded() {
        datesForMonthsToLoad?.removeAll()

        guard
            let visibleRange = visibleMonthsRange(),
            let months =
                visibleRange.components(
                    unitFlags: [.month],
                    for: calendar
                )
                .month
        else { return }

        for i in 0..<months {
            var dc = DateComponents()
            dc.month = i

            if let date = calendar.date(byAdding: dc, to: visibleRange.start) {
                let items = try? cachedMonths.object(forKey: date)
                if items == nil {
                    addMonthToLoadingQueue(monthStart: date)
                }
            }
        }
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        numberOfEventsAt date: Date
    ) -> Int {
        events(at: date).count
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        dateRangeForEventAt index: Int,
        date: Date
    ) -> DateRange {
        let events = events(at: date)
        let event = events[index]
        return .init(start: event.startDate, end: event.endDate)
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        cellForEventAt index: Int,
        date: Date
    ) -> EventView {
        guard
            let cell =
                monthPlanView.dequeueReusableCell(
                    withReuseIdentifier: ReusableConstants.Identifier.eventCell,
                    forEventAt: index,
                    date: date
                ) as? MonthStandardEventView
        else { return .init() }

        let event = event(at: index, date: date)

        cell.title = event.title
        cell.color = UIColor(cgColor: event.calendar.cgColor)

        return cell
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        cellForNewEventAt date: Date
    ) -> EventView {
        let cal = eventStore.defaultCalendarForNewEvents!
        let evCell = StandardEventView()
        evCell.title = "New Event..."
        evCell.color = UIColor(cgColor: cal.cgColor)
        return evCell
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        canMoveCellForEventAt index: Int,
        date: Date
    ) -> Bool {
        event(at: index, date: date).calendar.allowsContentModifications
    }

    lazy var titleDateFormatter: DateFormatter = {
        let format = DateFormatter()
        format.dateFormat = "d"
        format.calendar = calendar
        format.locale = .current
        return format
    }()

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        attributedStringForDayHeaderAt date: Date
    ) -> NSAttributedString? {
        nil
        //        let dayStr = titleDateFormatter.string(from: date)
        //        return NSAttributedString(string: dayStr)
    }

    public override func monthPlanViewDidScroll(_ monthPlanView: MonthPlanView) {
        guard
            let range = visibleMonthsRange(),
            range != visibleMonths
        else { return }

        self.visibleMonths = range
        loadEventsIfNeeded()

    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didSelectDayCellAt date: Date
    ) {
        //        fatalError("must subclass")
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didShow cell: EventView,
        forNewEventAt date: Date
    ) {
        let ev = EKEvent(eventStore: eventStore)
        ev.startDate = date
        ev.endDate = date
        ev.isAllDay = true

        print("monthPlanView didShow ev: \(ev)")
        //        [self showPopoverForNewEvent:ev withCell:cell];
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        willStartMovingEventAt index: Int,
        date: Date
    ) {

    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didMoveEventAt index: Int,
        fromDate: Date,
        toDate: Date
    ) {

    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        shouldSelectEventAt index: Int,
        date: Date
    ) -> Bool {
        true
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didSelectEventAt index: Int,
        date: Date
    ) {
        let event = event(at: index, date: date)
        print("didSelectEvent: \(event)")
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        shouldDeselectEventAt index: Int,
        date: Date
    ) -> Bool {
        false
    }

    public override func monthPlanView(
        _ monthPlanView: MonthPlanView,
        didDeselectEventAt index: Int,
        date: Date
    ) {

    }
}
