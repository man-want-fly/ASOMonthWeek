//
//  DayPlanEKViewController.swift
//  CalLib
//
//  Created by mwf on 2023/8/23.
//

import Cache
import EventKit
import EventKitUI
import OrderedCollections
import UIKit

public struct FetchEventType: OptionSet {

    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let timed = FetchEventType(rawValue: 1)
    static let allDay = FetchEventType(rawValue: 2)
    static let `any`: FetchEventType = [.timed, .allDay]
}

public protocol DayPlanEKViewControllerDelegate: AnyObject {

    func dayPlannerEKEViewController(
        _ controller: DayPlanEKViewController,
        willPresent eventViewController: EKEventViewController
    )

    func dayPlannerEKEViewController(
        _ controller: DayPlanEKViewController,
        navigationControllerFor presentingEventViewController: EKEventViewController
    ) -> UINavigationController
}

open class DayPlanEKViewController: DayPlanViewController {

    public var calendar: Calendar = .current {
        didSet {
            dayPlanView.calendar = calendar
        }
    }

    var visibleCalendars: Set<EKCalendar> = [] {
        didSet {
            dayPlanView.reloadAllEvents()
        }
    }

    let eventStore: EKEventStore

    private let eventKitSupport: EventKitSupport

    private let bgQueue: DispatchQueue = DispatchQueue(label: "DayPlanEKViewController.bgQueue")

    private var daysToLoad: OrderedSet<Date>?

    private var eventsCache: MemoryStorage<Date, [EKEvent]> = .init(
        config: .init(
            expiry: .never,
            countLimit: 400,
            totalCostLimit: 10 * 1024 * 1024
        )
    )

    private var createdEventType: Int?
    private var createdEventDate: Date?

    weak var delegate: DayPlanEKViewControllerDelegate?

    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
        self.eventKitSupport = .init(eventStore: eventStore)
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func reloadEvents() {
        daysToLoad?
            .forEach { date in
                dayPlanView.setActivityIndicator(visible: false, for: date)
            }

        daysToLoad?.removeAll()
        eventsCache.removeAll()

        fetchEvents(in: dayPlanView.visibleDays)

        dayPlanView.reloadAllEvents()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadEvents),
            name: .EKEventStoreChanged,
            object: nil
        )

        eventKitSupport.checkEventStoreAccess { granted in
            if granted {
                let calendars = self.eventStore.calendars(for: .event)
                self.visibleCalendars = Set(calendars)
                self.reloadEvents()
            }
        }

        dayPlanView.calendar = calendar
        dayPlanView.register(
            WeekAllDayEventView.self,
            forEventViewWithReuseIdentifier: String(describing: WeekAllDayEventView.self)
        )
        dayPlanView.register(
            StandardEventView.self,
            forEventViewWithReuseIdentifier: String(describing: StandardEventView.self)
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func fetchEvents(in dateRange: DateRange) {
        dateRange.start = calendar.startOfDay(for: dateRange.start)
        dateRange.end = calendar.nextStartOfDay(for: dateRange.end)

        dateRange.enumerateDays(with: calendar) { date, stop in
            let dayEnd = calendar.nextStartOfDay(for: date)
            let events = fetchEvents(from: date, to: dayEnd, calendars: nil)
            eventsCache.setObject(events, forKey: date)
        }
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

        guard eventKitSupport.accessGranted else { return [] }

        let events = eventStore.events(matching: predicate)
        return events.sorted(
            using: KeyPathComparator(\.startDate, order: .forward)
        )
    }

    private func loadEvents(at date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)

        let nonExist = try? !eventsCache.existsObject(forKey: dayStart)

        guard let nonExist, nonExist else { return false }

        dayPlanView.setActivityIndicator(visible: true, for: dayStart)

        if daysToLoad == nil {
            daysToLoad = []
        }

        daysToLoad?.append(dayStart)

        bgQueue.async(execute: bg_loadOneDay)

        return true
    }

    private func bg_loadOneDay() {
        var date: Date?

        DispatchQueue.main.sync {
            date = daysToLoad?.first

            if let dt = date {
                daysToLoad?.remove(dt)
            }

            if let dt = date, !dayPlanView.visibleDays.contains(dt) {
                date = nil
            }
        }

        if let date {
            bg_loadEvents(at: date)
        }
    }

    private func bg_loadEvents(at date: Date) {
        let dayStart = calendar.startOfDay(for: date)

        events(ofType: .any, forDay: dayStart)

        DispatchQueue.main.async {
            self.dayPlanView.reloadEvents(at: date)
            self.dayPlanView.setActivityIndicator(visible: false, for: dayStart)
        }
    }

    private func events(forDay date: Date) -> [EKEvent] {
        let dayStart = calendar.startOfDay(for: date)

        if let events = try? eventsCache.object(forKey: dayStart) {
            return events
        } else {
            let dayEnd = calendar.nextStartOfDay(for: dayStart)
            let events = fetchEvents(from: dayStart, to: dayEnd, calendars: nil)
            eventsCache.setObject(events, forKey: dayStart)
            return events
        }
    }

    private func events(
        ofType type: FetchEventType,
        forDay date: Date
    ) -> [EKEvent] {
        let events = events(forDay: date)

        var filteredEvents: [EKEvent] = []

        for event in events where visibleCalendars.contains(event.calendar) {
            if type.contains(.allDay) && event.isAllDay {
                filteredEvents.append(event)
            } else if type.contains(.timed) && !event.isAllDay {
                filteredEvents.append(event)
            }
        }

        return filteredEvents
    }

    private func event(
        ofType type: EventType,
        at index: Int,
        date: Date
    ) -> EKEvent? {
        let events = events(
            ofType: type == .allDay ? .allDay : .timed,
            forDay: date
        )
        return events[index]
    }

    // MARK: - DayPlanViewDataSource
    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        numberOfEventsOfType eventType: EventType,
        at date: Date
    ) -> Int {
        guard !loadEvents(at: date) else { return 0 }
        return events(
            ofType: eventType == .allDay ? .allDay : .timed,
            forDay: date
        )
        .count
    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        viewForEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> EventView? {
        switch eventType {
        case .allDay:
            guard
                let event = event(ofType: eventType, at: index, date: date),
                let cell = dayPlanView.dequeueReusableView(
                    for: eventType,
                    String(describing: WeekAllDayEventView.self),
                    at: index,
                    date: date
                ) as? WeekAllDayEventView
            else { return nil }

            cell.title = event.title
            cell.color = UIColor(cgColor: event.calendar.cgColor)

            return cell
        case .timed:
            guard
                let event = event(ofType: eventType, at: index, date: date),
                let cell = dayPlanView.dequeueReusableView(
                    for: eventType,
                    String(describing: StandardEventView.self),
                    at: index,
                    date: date
                ) as? StandardEventView
            else { return nil }

            cell.title = event.title
            cell.color = UIColor(cgColor: event.calendar.cgColor)

            return cell
        }

    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        dateRangeForEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> DateRange? {
        guard
            let event = event(
                ofType: eventType,
                at: index,
                date: date
            )
        else { return nil }

        var end = event.endDate
        if eventType == .allDay, let e = end {
            end = calendar.nextStartOfDay(for: e)
        }

        return DateRange(start: event.startDate, end: end!)
    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        shouldStartMovingEventOfType eventType: EventType,
        at index: Int,
        date: Date
    ) -> Bool {
        guard
            let event = event(
                ofType: eventType,
                at: index,
                date: date
            )
        else { return false }

        return event.calendar.allowsContentModifications
    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        canMoveEventOfType eventType: EventType,
        at index: Int,
        date: Date,
        toType targetType: EventType,
        toDate targetDate: Date
    ) -> Bool {
        guard
            let event = event(
                ofType: eventType,
                at: index,
                date: date
            )
        else { return false }

        return event.calendar.allowsContentModifications
    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        moveEventOfType eventType: EventType,
        at index: Int,
        date: Date,
        toType targetType: EventType,
        toDate targetDate: Date
    ) {
        guard
            let event = event(
                ofType: eventType,
                at: index,
                date: date
            )
        else { return }

        var components = calendar.dateComponents(
            [.minute],
            from: event.startDate,
            to: event.endDate
        )

        if event.isAllDay, targetType == .timed {
            components.minute = Int(dayPlanView.durationForNewTimedEvent) / 60
        }

        guard
            let end = calendar.date(
                byAdding: components,
                to: targetDate
            )
        else { return }

        event.isAllDay = targetType == .allDay
        event.startDate = targetDate
        event.endDate = end

        eventKitSupport.save(event: event) { [weak self] success in
            self?.dayPlanView.endInteraction()
        }
    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        viewForNewEventOfType eventType: EventType,
        at date: Date
    ) -> EventView? {
        let calendar = eventStore.defaultCalendarForNewEvents

        let view = StandardEventView()
        view.title = "New Event"
        view.color = UIColor(cgColor: calendar!.cgColor)
        return view
    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        didSelectEventOfType eventType: EventType,
        at index: Int,
        date: Date,
        completion: (() -> Void)?
    ) -> Bool {
        guard let event = event(ofType: eventType, at: index, date: date) else { return false }
        print("didSelectEventOfType event: \(event)")
        didSelect(event: event, date: date, completion: completion)
        return true
    }
    
    open func didSelect(event: EKEvent, date: Date, completion: (() -> Void)?) {
        
    }

    // MARK: - DayPlanViewDelegate
    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        willDisplay date: Date
    ) {
        let loading = loadEvents(at: date)
        if !loading {
            dayPlanView.setActivityIndicator(visible: false, for: date)
        }
    }

    open override func dayPlanView(
        _ dayPlanView: DayPlanView,
        didEndDisplaying date: Date
    ) {
        daysToLoad?.removeAll()
    }
}
