//
//  DayPlanView.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import Cache
import OrderedCollections
import Reusable
import UIKit

struct ScrollDirection: OptionSet {
    let rawValue: Int

    static let unknown: ScrollDirection = []
    static let left = ScrollDirection(rawValue: 1 << 0)
    static let up = ScrollDirection(rawValue: 1 << 1)
    static let right = ScrollDirection(rawValue: 1 << 2)
    static let down = ScrollDirection(rawValue: 1 << 3)
    static let horizontal: ScrollDirection = [.left, .right]
    static let vertical: ScrollDirection = [.up, .down]
}

public class DayPlanView: UIView {

    private let daysLoadingStep = 2
    private let minHourSlotHeight: CGFloat = 20
    private let maxHourSlotHeight: CGFloat = 150

    var calendar: Calendar = .current

    var numberOfVisibleDays = 7 {
        didSet {
            assert(
                numberOfVisibleDays > 0,
                "numberOfVisibleDays in day planner view cannot be set to 0"
            )

            guard numberOfLoadedDays != oldValue else { return }
            let date = visibleDays.start

            if let dateRange,
                dateRange.components(
                    unitFlags: [.day],
                    for: calendar
                )
                .day! < numberOfVisibleDays
            {
                return
            }

            reloadCollectionViews()
            scroll(to: date, options: .date, animated: false)
        }
    }

    var dayColumnSize: CGSize {
        let height = hourSlotHeight * CGFloat(hourRange.length) + eventsViewInnerMargin * 2
        let numOfDays = min(numberOfVisibleDays, numberOfLoadedDays)
        let width = (bounds.width - timeColumnWidth) / CGFloat(numOfDays)
        return CGSize(width: width, height: height).aligned
    }

    private var _hourSlotHeight: CGFloat = 65
    var hourSlotHeight: CGFloat {
        get {
            _hourSlotHeight
        }
        set {
            let yCenterOffset = timeScrollView.contentOffset.y + timeScrollView.bounds.height * 0.5
            let time = time(fromYOffset: yCenterOffset, rounding: 0)

            _hourSlotHeight = min(
                max(newValue.aligned, minHourSlotHeight),
                maxHourSlotHeight
            )

            dayColumnsView.collectionViewLayout.invalidateLayout()

            timedEventsViewLayout.dayColumnSize = dayColumnSize
            timedEventsViewLayout.invalidateLayout()

            timeRowsView.hourSlotHeight = _hourSlotHeight

            timeScrollView.contentSize = .init(
                width: bounds.width,
                height: dayColumnSize.height
            )

            timeRowsView.frame = .init(
                x: 0,
                y: 0,
                width: timeScrollView.contentSize.width,
                height: timeScrollView.contentSize.height
            )

            var yOffset = offset(from: time, rounding: 0) - timeScrollView.bounds.height * 0.5
            yOffset = max(
                0,
                min(
                    yOffset,
                    timeScrollView.contentSize.height - timeScrollView.bounds.height
                )
            )

            timeScrollView.contentOffset = .init(x: 0, y: yOffset)
            timedEventsView.contentOffset = .init(
                x: timedEventsView.contentOffset.x,
                y: yOffset
            )
        }
    }

    var timeColumnWidth: CGFloat = 60

    public var dayHeaderHeight: CGFloat = 56 {
        didSet {
            guard dayHeaderHeight != oldValue else { return }
            setupSubviews()
        }
    }

    var daySeparatorsColor: UIColor = .separator

    var timeSeparatorsColor: UIColor = .separator

    var currentTimeColor: UIColor = .tintColor

    var showsAllDayEvents: Bool = true {
        didSet {
            guard showsAllDayEvents != oldValue else { return }

            allDayEventsView.reloadData()
            dayColumnsView.reloadData()  // for dots indicating events
            dayColumnsView.performBatchUpdates {

            } completion: { _ in
                self.setupSubviews()
            }
        }
    }

    public var backgroundView: UIView?

    public var dateFormat: String = "d MMM\neeeee"

    private var _dateRange: DateRange?
    public var dateRange: DateRange? {
        set {
            if dateRange != newValue {
                var firstDate = visibleDays.start

                _dateRange = nil

                if let dateRange {
                    _dateRange = .init(
                        start: calendar.startOfDay(for: dateRange.start),
                        end: calendar.startOfDay(for: dateRange.end)
                    )

                    // adjust startDate so that it falls inside new range
                    if let _dateRange, !_dateRange.includes(loadedDaysRange) {
                        startDate = _dateRange.start
                    }

                    if let _dateRange, !_dateRange.contains(firstDate) {
                        firstDate = Date()
                        if !_dateRange.contains(firstDate) {
                            firstDate = _dateRange.start
                        }
                    }
                }

                reloadCollectionViews()
                scroll(to: firstDate, options: .date, animated: false)
            }
        }
        get {
            _dateRange
        }
    }

    var hourRange: NSRange = .init(location: 0, length: 24)

    var dimmingColor: UIColor = UIColor(white: 0.9, alpha: 0.5)
    var pagingEnabled: Bool = true
    var zoomingEnabled: Bool = true
    var canCreateEvents: Bool = true
    var canMoveEvents: Bool = true
    var allowsSelection: Bool = true

    var durationForNewTimedEvent: TimeInterval = 60 * 60

    weak var dataSource: DayPlanViewDataSource?
    weak var delegate: DayPlanViewDelegate?

    var eventCoveringType: DayPlanCoveringType = .classic

    var visibleDays: DateRange {
        let dayWidth = dayColumnSize.width

        let first = floor(timedEventsView.contentOffset.x / dayWidth)
        var firstDay = date(fromDayOffset: Int(first))
        if let dateRange, firstDay.compare(dateRange.start) == .orderedAscending {
            firstDay = dateRange.start
        }

        // Since the day column width is rounded, there can be a difference of a few points between
        // the right side of the view bounds and the limit of the last column, causing the last visible day
        // to be one more than expected. We have to take this into account.
        let diff = timedEventsView.bounds.width - dayColumnSize.width * CGFloat(numberOfVisibleDays)

        let last = ceil((timedEventsView.bounds.maxX - diff) / dayWidth)
        var lastDay = date(fromDayOffset: Int(last))
        if let dateRange, lastDay.compare(dateRange.end) != .orderedAscending {
            lastDay = dateRange.end
        }

        return DateRange(start: firstDay, end: lastDay)
    }

    var firstVisibleTime: TimeInterval {
        let ti = time(
            fromYOffset: timedEventsView.contentOffset.y,
            rounding: 0
        )
        return fmax(Double(hourRange.location) * 3600, ti)
    }

    var lastVisibleTime: TimeInterval {
        let ti = time(
            fromYOffset: timedEventsView.bounds.maxY,
            rounding: 0
        )
        return fmin(Double(NSMaxRange(hourRange)) * 3600, ti)
    }

    var selectedEventView: EventView? {
        guard
            let selectedCellIndexPath,
            let selectedCellType
        else { return nil }

        return collectionViewCell(
            for: selectedCellType,
            at: selectedCellIndexPath
        )?
        .eventView
    }

    lazy var timedEventsViewLayout: TimedEventsViewLayout = {
        let layout = TimedEventsViewLayout()
        layout.delegate = self
        layout.dayColumnSize = dayColumnSize
        layout.coveringType = eventCoveringType == .complex ? .complex : .classic
        return layout
    }()

    lazy var allDayEventsViewLayout: AllDayEventsViewLayout = {
        let layout = AllDayEventsViewLayout()
        layout.delegate = self
        layout.dayColumnWidth = dayColumnSize.width
        layout.eventCellHeight = allDayEventCellHeight
        return layout
    }()

    /// EventView
    private let reusableQueue = ReusableObjectQueue()

    private var _startDate: Date?
    var startDate: Date {
        set {
            _startDate = calendar.startOfDay(for: newValue)
        }
        get {
            if let _startDate {
                return _startDate
            } else {
                var date = calendar.startOfDay(for: Date())
                if let dateRange, !dateRange.contains(date) {
                    date = dateRange.start
                }
                _startDate = date
                return date
            }
        }
    }

    var maxStartDate: Date? {
        guard let dateRange else { return nil }

        let date = calendar.date(
            byAdding: DateComponents(
                day: -(2 * daysLoadingStep + 1) * numberOfVisibleDays
            ),
            to: dateRange.end,
            wrappingComponents: false
        )

        if var date, date.compare(dateRange.start) == .orderedAscending {
            date = dateRange.start
        }

        return date
    }

    var numberOfLoadedDays: Int {
        var numDays = (2 * daysLoadingStep + 1) * numberOfVisibleDays
        if let dateRange = dateRange {
            let diff =
                calendar.dateComponents(
                    [.day],
                    from: dateRange.start,
                    to: dateRange.end
                )
                .day!
            numDays = min(numDays, diff)  // cannot load more than the total number of scrollable days
        }
        return numDays
    }

    var loadedDaysRange: DateRange {
        let comps = DateComponents(day: numberOfLoadedDays)
        let endDate = calendar.date(byAdding: comps, to: startDate)
        return DateRange(start: startDate, end: endDate!)
    }

    var previousVisibleDays: DateRange?

    var loadingDays: OrderedSet<Date> = .init(minimumCapacity: 14)

    var firstVisibleDate: Date {
        let xOffset = timedEventsView.contentOffset.x
        let section = ceil(xOffset / dayColumnSize.width)
        return date(fromDayOffset: Int(section))
    }

    var allDayEventCellHeight: CGFloat = 20
    var eventsViewInnerMargin: CGFloat = 15

    var controllingScrollView: UIScrollView?

    var scrollStartOffset: CGPoint = .zero

    var scrollDirection: ScrollDirection = .unknown

    var scrollTargetDate: Date?

    var interactiveCell: InteractiveEventView?
    var interactiveCellTouchPoint: CGPoint = .zero
    var interactiveCellType: EventType?
    var interactiveCellDate: Date?
    var interactiveCellTimedEventHeight: CGFloat?
    var isInteractiveCellForNewEvent: Bool?

    var movingEventType: EventType?
    var movingEventIndex: Int?
    var movingEventDate: Date?
    var acceptsTarget: Bool?

    var dragTimer: Timer?

    var selectedCellIndexPath: IndexPath?
    var selectedCellType: EventType?

    var hourSlotHeightForGesture: CGFloat?

    var scrollViewAnimationCompletionBlock: (() -> Void)?

    var dimmedTimeRangesCache: MemoryStorage<Date, [DateRange]> = .init(
        config: .init(
            expiry: .never,
            countLimit: 500,
            totalCostLimit: 10 * 1024 * 1024
        )
    )

    private lazy var timedEventsView: UICollectionView = {
        let view = UICollectionView(
            frame: .zero,
            collectionViewLayout: timedEventsViewLayout
        )
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.scrollsToTop = false
        view.decelerationRate = .fast
        view.allowsSelection = false
        view.isDirectionalLockEnabled = true

        view.register(cellType: EventCell.self)
        view.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: ReusableConstants.Kind.dimmingView,
            withReuseIdentifier: ReusableConstants.Identifier.dimmingView
        )

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        view.addGestureRecognizer(longPress)

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

        return view
    }()

    private lazy var allDayEventsView: UICollectionView = {
        let view = UICollectionView(
            frame: .zero,
            collectionViewLayout: allDayEventsViewLayout
        )
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.showsVerticalScrollIndicator = true
        view.showsHorizontalScrollIndicator = false
        view.decelerationRate = .fast
        view.allowsSelection = false
        view.isDirectionalLockEnabled = true
        view.register(cellType: EventCell.self)
        view.register(
            UICollectionReusableView.self,
            forSupplementaryViewOfKind: ReusableConstants.Kind.moreEvents,
            withReuseIdentifier: ReusableConstants.Identifier.moreEventsView
        )

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        view.addGestureRecognizer(longPress)

        let tap = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        return view
    }()

    private lazy var allDayEventsBackgroundView = BorderedAllDayBackgroundView()

    private lazy var dayColumnsView: UICollectionView = {
        let layout = DayColumnViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.dataSource = self
        view.delegate = self
        view.showsHorizontalScrollIndicator = false
        view.decelerationRate = .fast
        view.isScrollEnabled = false
        view.allowsSelection = false

        view.register(cellType: DayColumnCell.self)
        return view
    }()

    private lazy var timeScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.isScrollEnabled = false

        scrollView.addSubview(timeRowsView)
        return scrollView
    }()

    private lazy var timeRowsView: TimeRowsView = {
        let timeRowsView = TimeRowsView()
        timeRowsView.delegate = self
        timeRowsView.timeColor = timeSeparatorsColor
        timeRowsView.currentTimeColor = currentTimeColor
        timeRowsView.hourSlotHeight = hourSlotHeight
        timeRowsView.hourRange = hourRange
        timeRowsView.insetsHeight = eventsViewInnerMargin
        timeRowsView.timeColumnWidth = timeColumnWidth
        timeRowsView.contentMode = .redraw
        return timeRowsView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setup() {
        autoresizesSubviews = false
        showsAllDayEvents = true

        allDayEventsBackgroundView.timeColumnWidth = timeColumnWidth

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillChangeStatusBarOrientation),
            name: UIApplication.willChangeStatusBarFrameNotification,
            object: nil
        )
    }

    @objc private func applicationDidReceiveMemoryWarning() {
        reloadAllEvents()
    }

    @objc private func applicationWillChangeStatusBarOrientation() {
        endInteraction()

        timedEventsView.panGestureRecognizer.isEnabled = false
        timedEventsView.panGestureRecognizer.isEnabled = true

        allDayEventsView.panGestureRecognizer.isEnabled = false
        allDayEventsView.panGestureRecognizer.isEnabled = true
    }

    @objc private func handleLongPress(
        _ gesture: UILongPressGestureRecognizer
    ) {
        let ptSelf = gesture.location(in: self)
        // long press on a cell or an empty space in the view
        if gesture.state == .began {
            endInteraction()  // in case previous interaction did not end properly

            self.isUserInteractionEnabled = false

            // where did the gesture start ?
            let view = gesture.view as! UICollectionView
            let type: EventType = (view == timedEventsView) ? .timed : .allDay
            let path = view.indexPathForItem(at: gesture.location(in: view))

            if let indexPath = path {  // a cell was touched
                if !beginMovingEvent(type, at: indexPath) {
                    gesture.isEnabled = false
                    gesture.isEnabled = true
                } else {
                    interactiveCellTouchPoint = gesture.location(in: interactiveCell)
                }
            } else {  // an empty space was touched
                let createEventSlotHeight = floor(
                    durationForNewTimedEvent * hourSlotHeight / 60.0 / 60.0
                )
                let date = date(
                    at: CGPoint(
                        x: ptSelf.x,
                        y: ptSelf.y - createEventSlotHeight / 2
                    ),
                    rounded: true
                )

                if let date, !beginCreateEvent(type, at: date) {
                    gesture.isEnabled = false
                    gesture.isEnabled = true
                }
            }
        }
        // interactive cell was moved
        else if gesture.state == .changed {
            moveInteractiveCell(at: gesture.location(in: self))
        }
        // finger was lifted
        else if gesture.state == .ended {
            dragTimer?.invalidate()
            dragTimer = nil
            //[self scrollViewDidEndScrolling:self.controllingScrollView];

            let date = date(at: interactiveCell!.frame.origin, rounded: true)

            if !isInteractiveCellForNewEvent! {  // existing event
                if !acceptsTarget! {
                    endInteraction()
                } else if let date, let dataSource {
                    dataSource.dayPlanView(
                        self,
                        moveEventOfType: movingEventType!,
                        at: movingEventIndex!,
                        date: movingEventDate!,
                        toType: interactiveCellType!,
                        toDate: date
                    )
                }
            } else {  // new event
                if !acceptsTarget! {
                    endInteraction()
                } else if let date, let dataSource {
                    dataSource.dayPlanView(
                        self,
                        createNewEventOfType: interactiveCellType!,
                        at: date
                    )
                }
            }

            isUserInteractionEnabled = true
            //[self endInteraction];
        } else if gesture.state == .cancelled {
            isUserInteractionEnabled = true
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        deselectEvent(tellDelegate: true)  // deselect previous

        guard let view = gesture.view as? UICollectionView else {
            return
        }

        let pt = gesture.location(in: view)

        guard let path = view.indexPathForItem(at: pt) else { return }

        let date = date(fromDayOffset: path.section)

        selectEvent(
            tellDelegate: true,
            eventType: view == timedEventsView ? .timed : .allDay,
            at: path.item,
            date: date
        )
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard zoomingEnabled else { return }

        if gesture.state == .began {
            hourSlotHeightForGesture = hourSlotHeight
        } else if gesture.state == .changed {
            if gesture.numberOfTouches > 1 {
                let height = hourSlotHeightForGesture! * gesture.scale

                if hourSlotHeight != height {
                    hourSlotHeight = height

                    delegate?.dayPlanViewDidZoom(self)
                }
            }
        }
    }

    @objc private func dragTimerDidFire(_ timer: Timer) {
        guard
            let info = timer.userInfo as? [String: Any],
            let value = info["direction"] as? Int
        else { return }

        let direction = ScrollDirection(rawValue: value)

        var offset = timedEventsView.contentOffset

        switch direction {
        case .left:
            offset.x += dayColumnSize.width
            offset.x = min(
                offset.x,
                timedEventsView.contentSize.width - timedEventsView.bounds.size.width
            )
        case .right:
            offset.x -= dayColumnSize.width
            offset.x = max(offset.x, 0)

        case .down:
            offset.y += 20
            offset.y = min(
                offset.y,
                timedEventsView.contentSize.height - timedEventsView.bounds.size.height
            )
        case .up:
            offset.y -= 20
            offset.y = max(offset.y, 0)

        default: break
        }

        // This test is important, because if we can't move (at the start or end of content),
        // setContentOffset will have no effect, and will not send scrollViewDidEndScrollingAnimation:
        // so we won't get any chance to reset everything
        if timedEventsView.contentOffset != offset {
            setTimedEventsView(
                contentOffset: offset,
                animated: false,
                completion: {}
            )
            // scrolling will be enabled again in scrollViewDidEndScrolling:
        }
    }

    private func moveInteractiveCell(at point: CGPoint) {
        let rightScrollRect = CGRect(
            x: bounds.maxX - 30,
            y: 0,
            width: 30,
            height: bounds.size.height
        )
        let leftScrollRect = CGRect(
            x: 0,
            y: 0,
            width: timeColumnWidth + 20,
            height: bounds.size.height
        )
        let downScrollRect = CGRect(
            x: timeColumnWidth,
            y: bounds.maxY - 30,
            width: bounds.size.width,
            height: 30
        )
        let upScrollRect = CGRect(
            x: timeColumnWidth,
            y: timedEventsView.frame.origin.y,
            width: bounds.size.width,
            height: 30
        )

        if let dragTimer {
            dragTimer.invalidate()
            self.dragTimer = nil
        }

        // speed depends on day column width
        let ti = (dayColumnSize.width / 100) * 0.05

        if rightScrollRect.contains(point) {
            // progressive speed
            let speed = ti / (point.x - rightScrollRect.origin.x) / 30
            dragTimer = Timer.scheduledTimer(
                timeInterval: speed,
                target: self,
                selector: #selector(dragTimerDidFire(_:)),
                userInfo: ["direction": ScrollDirection.left.rawValue],
                repeats: true
            )
        } else if leftScrollRect.contains(point) {
            let speed = ti / (leftScrollRect.maxX - point.x) / 30
            dragTimer = Timer.scheduledTimer(
                timeInterval: speed,
                target: self,
                selector: #selector(dragTimerDidFire(_:)),
                userInfo: ["direction": ScrollDirection.right.rawValue],
                repeats: true
            )
        } else if downScrollRect.contains(point) {
            dragTimer = Timer.scheduledTimer(
                timeInterval: 0.05,
                target: self,
                selector: #selector(dragTimerDidFire(_:)),
                userInfo: ["direction": ScrollDirection.down.rawValue],
                repeats: true
            )
        } else if upScrollRect.contains(point) {
            dragTimer = Timer.scheduledTimer(
                timeInterval: 0.05,
                target: self,
                selector: #selector(dragTimerDidFire(_:)),
                userInfo: ["direction": ScrollDirection.up.rawValue],
                repeats: true
            )
        }

        updateMovingCell(at: point)
    }

    private func updateMovingCell(at point: CGPoint) {
        let ptDayColumnsView = convert(point, to: dayColumnsView)
        var ptEventsView = timedEventsView.convert(point, from: self)

        let section = Int(ptDayColumnsView.x / dayColumnSize.width)
        var origin = CGPoint(
            x: CGFloat(section) * dayColumnSize.width,
            y: ptDayColumnsView.y
        )
        origin = convert(origin, from: dayColumnsView)

        var size = interactiveCell!.frame.size  // cell size

        var type: EventType = .timed
        if showsAllDayEvents && point.y < timedEventsView.frame.minY {
            type = .allDay
        }

        let didTransition = type != interactiveCellType
        interactiveCellType = type
        acceptsTarget = true

        let date = date(at: interactiveCell!.frame.origin, rounded: true)
        interactiveCellDate = date

        if let isInteractiveCellForNewEvent, isInteractiveCellForNewEvent {
            if let date,
                let dataSource,
                !dataSource.dayPlanView(
                    self,
                    canCreateNewEventOfType: type,
                    at: date
                )
            {
                acceptsTarget = false
            }
        } else {
            if let dataSource,
                let date,
                let movingEventIndex,
                let movingEventDate,
                !dataSource.dayPlanView(
                    self,
                    canMoveEventOfType: type,
                    at: movingEventIndex,
                    date: movingEventDate,
                    toType: type,
                    toDate: date
                )
            {
                acceptsTarget = false
            }
        }

        interactiveCell?.forbiddenSignVisible = !acceptsTarget!

        if interactiveCellType == .timed {
            size.height = interactiveCellTimedEventHeight!

            // constraint position
            ptEventsView.y -= interactiveCellTouchPoint.y
            ptEventsView.y = max(ptEventsView.y, eventsViewInnerMargin)
            ptEventsView.y = min(
                ptEventsView.y,
                timedEventsView.contentSize.height - eventsViewInnerMargin
            )

            origin.y = convert(ptEventsView, from: timedEventsView).y
            origin.y = max(origin.y, timedEventsView.frame.minY)

            timeRowsView.timeMark = time(
                fromYOffset: ptEventsView.y,
                rounding: 0
            )
        } else {
            size.height = allDayEventCellHeight
            origin.y = allDayEventsView.frame.minY  // top of the view
        }

        var cellFrame = interactiveCell!.frame

        let animationDur: TimeInterval = (origin.x != cellFrame.minX) ? 0.02 : 0.15

        cellFrame.origin = origin
        cellFrame.size = size

        UIView.animate(
            withDuration: animationDur,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.interactiveCell?.frame = cellFrame
            },
            completion: { finished in
                if didTransition {
                    self.interactiveCell?.eventView?
                        .didTransition(
                            to: self.interactiveCellType!
                        )
                }
            }
        )
    }

    private func beginCreateEvent(
        _ eventType: EventType,
        at date: Date
    ) -> Bool {
        assert(
            visibleDays.contains(date),
            "beginCreateEventOfType:atDate for non visible date"
        )

        guard canCreateEvents else { return false }

        interactiveCellTimedEventHeight = floor(
            durationForNewTimedEvent * hourSlotHeight / 60.0 / 60.0
        )

        isInteractiveCellForNewEvent = true
        interactiveCellType = eventType
        interactiveCellTouchPoint = CGPoint(
            x: 0,
            y: interactiveCellTimedEventHeight! / 2
        )
        interactiveCellDate = date

        interactiveCell = InteractiveEventView()

        if let newEventView = dataSource?
            .dayPlanView(
                self,
                viewForNewEventOfType: eventType,
                at: date
            )
        {
            interactiveCell?.eventView = newEventView
            assert(
                interactiveCell != nil,
                "dayPlannerView:viewForNewEventOfType:atDate can't return nil"
            )
        } else {
            let eventView = StandardEventView()
            eventView.title = NSLocalizedString("New Event", comment: "")
            interactiveCell?.eventView = eventView
        }

        acceptsTarget = true
        if let canCreateNewEvent = dataSource?
            .dayPlanView(
                self,
                canCreateNewEventOfType: eventType,
                at: date
            ),
            !canCreateNewEvent
        {
            interactiveCell?.forbiddenSignVisible = true
            acceptsTarget = false
        }

        let rect = rect(forNewEventType: eventType, at: date)
        interactiveCell?.frame = rect
        addSubview(interactiveCell!)
        interactiveCell?.isHidden = false

        return true
    }

    private func beginMovingEvent(
        _ eventType: EventType,
        at indexPath: IndexPath
    ) -> Bool {
        guard canMoveEvents else { return false }

        let view = eventType == .timed ? timedEventsView : allDayEventsView
        let date = date(fromDayOffset: indexPath.section)

        let shouldStartMoving = dataSource?
            .dayPlanView(
                self,
                shouldStartMovingEventOfType: eventType,
                at: indexPath.item,
                date: date
            )

        if shouldStartMoving == false {
            if let cell = view.cellForItem(at: indexPath) as? EventCell {
                bounceAnimateCell(cell)
            }
            return false
        }

        movingEventType = eventType
        movingEventIndex = indexPath.item

        isInteractiveCellForNewEvent = false
        interactiveCellType = eventType

        let cell = view.cellForItem(at: indexPath) as? EventCell
        let eventView = cell?.eventView

        interactiveCell = InteractiveEventView()
        interactiveCell?.eventView = eventView?.copy() as? EventView

        var frame = convert(cell!.frame, from: view)
        if eventType == .timed {
            frame.size.width = dayColumnSize.width
        }
        interactiveCell?.frame = frame

        interactiveCellDate = self.date(
            at: interactiveCell!.frame.origin,
            rounded: true
        )
        movingEventDate = interactiveCellDate

        interactiveCellTimedEventHeight =
            eventType == .timed
            ? frame.height : hourSlotHeight

        acceptsTarget = true

        addSubview(interactiveCell!)
        interactiveCell?.isHidden = false

        return true
    }

    private func bounceAnimateCell(_ eventCell: EventCell) {
        let frame = eventCell.frame
        UIView.animate(withDuration: 0.2) {
            eventCell.frame = eventCell.frame.insetBy(dx: -4, dy: -2)
        } completion: { _ in
            eventCell.frame = frame
        }
    }

    private func rect(
        forNewEventType eventType: EventType,
        at date: Date
    ) -> CGRect {
        let section = dayOffset(from: date)
        let x = CGFloat(section) * dayColumnSize.width

        switch eventType {
        case .allDay:
            let rect = CGRect(
                x: x,
                y: 0,
                width: dayColumnSize.width,
                height: allDayEventCellHeight
            )
            return convert(rect, from: allDayEventsView)

        case .timed:
            let y = offset(from: durationForNewTimedEvent, rounding: 0)
            let rect = CGRect(
                x: x,
                y: y,
                width: dayColumnSize.width,
                height: interactiveCellTimedEventHeight!
            )
            return convert(rect, from: timedEventsView)
        }
    }

    private func setupSubviews() {
        var allDayEventsViewHeight: CGFloat = 0.5

        if showsAllDayEvents {
            allDayEventsViewHeight = fmax(
                allDayEventsViewHeight,
                fmin(
                    allDayEventsView.contentSize.height,
                    allDayEventCellHeight * 2.5 + 6
                )
            )
        }

        let timedEventViewTop = dayHeaderHeight + allDayEventsViewHeight
        let timedEventsViewWidth = bounds.width - timeColumnWidth
        let timedEventsViewHeight = bounds.height - (dayHeaderHeight + allDayEventsViewHeight)

        backgroundView?.frame = .init(
            x: 0,
            y: timedEventViewTop,
            width: bounds.width,
            height: timedEventsViewHeight
        )
        if let backgroundView, backgroundView.superview == nil {
            addSubview(backgroundView)
        }

        allDayEventsBackgroundView.frame = .init(
            x: -1,
            y: dayHeaderHeight,
            width: bounds.width + 2,
            height: allDayEventsViewHeight
        )
        if allDayEventsBackgroundView.superview == nil {
            addSubview(allDayEventsBackgroundView)
        }

        UIView.animate(withDuration: 0.3, delay: 0, options: .layoutSubviews) {
            self.allDayEventsView.frame = .init(
                x: self.timeColumnWidth,
                y: self.dayHeaderHeight,
                width: timedEventsViewWidth,
                height: allDayEventsViewHeight
            )
        }

        if allDayEventsView.superview == nil {
            addSubview(allDayEventsView)
        }

        timedEventsView.frame = .init(
            x: timeColumnWidth,
            y: timedEventViewTop,
            width: timedEventsViewWidth,
            height: timedEventsViewHeight
        )
        if timedEventsView.superview == nil {
            addSubview(timedEventsView)
        }

        timeScrollView.contentSize = .init(width: bounds.width, height: dayColumnSize.height)
        timeRowsView.frame = .init(
            x: 0,
            y: 0,
            width: timeScrollView.contentSize.width,
            height: timeScrollView.contentSize.height
        )
        timeScrollView.frame = .init(
            x: 0,
            y: timedEventViewTop,
            width: bounds.width,
            height: timedEventsViewHeight
        )
        if timeScrollView.superview == nil {
            addSubview(timeScrollView)
        }

        timeRowsView.showsCurrentTime = visibleDays.contains(Date())

        timeScrollView.isUserInteractionEnabled = false

        dayColumnsView.frame = .init(
            x: timeColumnWidth,
            y: 0,
            width: timedEventsViewWidth,
            height: bounds.height
        )
        if dayColumnsView.superview == nil {
            addSubview(dayColumnsView)
        }
        dayColumnsView.isUserInteractionEnabled = false

        dayColumnsView.contentOffset = .init(x: timedEventsView.contentOffset.x, y: 0)
        timeScrollView.contentOffset = .init(x: 0, y: timedEventsView.contentOffset.y)
        allDayEventsView.contentOffset = .init(
            x: timedEventsView.contentOffset.x,
            y: allDayEventsView.contentOffset.y
        )

        if dragTimer == nil, let interactiveCell, let interactiveCellDate {
            var frame = interactiveCell.frame
            frame.origin = offset(from: interactiveCellDate, eventType: interactiveCellType!)
            frame.size.width = dayColumnSize.width
            interactiveCell.frame = frame
            interactiveCell.isHidden =
                interactiveCellType == .timed && !timedEventsView.frame.intersects(frame)
        }

        allDayEventsView.flashScrollIndicators()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        let dayColumnSize = dayColumnSize

        timeRowsView.hourSlotHeight = hourSlotHeight
        timeRowsView.timeColumnWidth = timeColumnWidth
        timeRowsView.insetsHeight = eventsViewInnerMargin

        timedEventsViewLayout.dayColumnSize = dayColumnSize

        allDayEventsViewLayout.dayColumnWidth = dayColumnSize.width
        allDayEventsViewLayout.eventCellHeight = allDayEventCellHeight

        setupSubviews()
        updateVisibleDaysRange()
    }

    public override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard traitCollection != previousTraitCollection else { return }
        allDayEventsView.collectionViewLayout.invalidateLayout()
    }

    private func updateVisibleDaysRange() {
        let oldRange = previousVisibleDays
        let newRange = visibleDays

        guard oldRange != newRange else { return }

        if let oldRange, oldRange.intersects(newRange) {
            let range = oldRange
            range.union(newRange)

            range.enumerateDays(with: calendar) { date, stop in
                if oldRange.contains(date), !newRange.contains(date) {
                    delegate?.dayPlanView(self, didEndDisplaying: date)
                } else if newRange.contains(date), !oldRange.contains(date) {
                    delegate?.dayPlanView(self, willDisplay: date)
                }
            }
        } else {
            oldRange?
                .enumerateDays(with: calendar) { date, stop in
                    delegate?.dayPlanView(self, didEndDisplaying: date)
                }
            newRange.enumerateDays(with: calendar) { date, stop in
                delegate?.dayPlanView(self, willDisplay: date)
            }
        }

        previousVisibleDays = newRange
    }

    public func scroll(to date: Date, options: DayPlanScrollType, animated: Bool) {
        guard controllingScrollView == nil else { return }

        var firstVisible = date

        if let maxScrollable = maxScrollableDate,
            firstVisible.compare(maxScrollable) == .orderedDescending
        {
            firstVisible = maxScrollable
        }

        let dayStart = calendar.startOfDay(for: firstVisible)
        scrollTargetDate = dayStart

        let time = date.timeIntervalSince(dayStart)
        var y = offset(from: time, rounding: 0) - 40

        y = fmax(
            fmin(
                y,
                (timedEventsView.contentSize.height - timedEventsView.bounds.height).aligned
            ),
            0
        )

        let x = xOffset(fromDayOffset: dayOffset(from: dayStart))

        var offset = timedEventsView.contentOffset

        let completion: () -> Void = { [weak self] in
            guard let self else { return }
            self.isUserInteractionEnabled = true
            if !animated {
                self.delegate?.dayPlanView(self, didScroll: options)
            }
        }

        switch options {
        case .dateTime:
            isUserInteractionEnabled = false
            offset.x = x
            setTimedEventsView(
                contentOffset: offset,
                animated: animated
            ) { [weak self] in
                let offset = CGPoint(
                    x: self?.timedEventsView.contentOffset.x ?? 0,
                    y: y
                )
                self?
                    .setTimedEventsView(
                        contentOffset: offset,
                        animated: animated,
                        completion: completion
                    )
            }

        case .date:
            isUserInteractionEnabled = false
            offset.x = x
            setTimedEventsView(
                contentOffset: offset,
                animated: animated,
                completion: completion
            )

        case .time:
            isUserInteractionEnabled = false
            offset.y = y
            setTimedEventsView(
                contentOffset: offset,
                animated: animated,
                completion: completion
            )
        }
    }

    func pageForward(animated: Bool, date: inout Date) {
        let next = nextDate(forPagingAfter: visibleDays.start)
        date = next
        scroll(to: next, options: .date, animated: animated)
    }

    func pageBackward(animated: Bool, date: inout Date) {
        let pre = previousDate(forPagingBefore: firstVisibleDate)
        date = pre
        scroll(to: pre, options: .date, animated: animated)
    }

    func register(
        _ viewClass: AnyClass,
        forEventViewWithReuseIdentifier identifier: String
    ) {
        reusableQueue.register(
            viewClass,
            forObjectWithReuseIdentifier: identifier
        )
    }

    func dequeueReusableView(
        for eventType: EventType,
        _ reuseIdentifier: String,
        at index: Int,
        date: Date
    ) -> EventView? {
        reusableQueue.dequeue(by: reuseIdentifier) as? EventView
    }

    func numberOfTimedEvents(at date: Date) -> Int {
        let section = dayOffset(from: date)
        return timedEventsView.numberOfItems(inSection: section)
    }

    func numberOfAllDayEvents(at date: Date) -> Int {
        guard showsAllDayEvents else { return 0 }

        let section = dayOffset(from: date)
        return allDayEventsView.numberOfItems(inSection: section)
    }

    func visibleEventViews(by type: EventType) -> [EventView] {
        var views = [EventView]()

        switch type {
        case .allDay:
            if let visibleCells = allDayEventsView.visibleCells as? [EventCell] {
                views.append(contentsOf: visibleCells.compactMap(\.eventView))
            }
        case .timed:
            if let visibleCells = timedEventsView.visibleCells as? [EventCell] {
                views.append(contentsOf: visibleCells.compactMap(\.eventView))
            }
        }

        return views
    }

    func date(at point: CGPoint, rounded: Bool) -> Date? {
        guard dayColumnsView.contentSize.width != .zero else { return nil }

        let ptDayColumnsView = convert(point, to: dayColumnsView)
        let dayPath = dayColumnsView.indexPathForItem(at: ptDayColumnsView)

        if let dayPath {
            // get the day/month/year portion of the date
            var date = date(fromDayOffset: dayPath.section)

            // get the time portion
            let ptTimedEventsView = convert(point, to: timedEventsView)
            if timedEventsView.point(inside: ptTimedEventsView, with: nil) {
                // max time for is 23:59
                let time = min(
                    time(fromYOffset: ptTimedEventsView.y, rounding: 15),
                    24 * 3600 - 60
                )
                date = date.addingTimeInterval(time)
            }
            return date
        }

        return nil
    }

    func eventView(
        at point: CGPoint,
        eventType: inout EventType,
        index: inout Int,
        date: inout Date
    ) -> EventView? {

        let ptTimedEventsView = convert(point, to: timedEventsView)
        let ptAllDayEventsView = convert(point, to: allDayEventsView)

        if timedEventsView.point(inside: ptTimedEventsView, with: nil) {
            if let path = timedEventsView.indexPathForItem(at: ptTimedEventsView),
                let cell = timedEventsView.cellForItem(at: path) as? EventCell
            {
                //                if eventType { &eventType = .timed }
                //                if index { &index = path.item }
                //                if date { &date = self.date(fromDayOffset: path.section) }
                return cell.eventView
            }
        } else if allDayEventsView.point(inside: ptAllDayEventsView, with: nil) {
            if let path = allDayEventsView.indexPathForItem(at: ptAllDayEventsView),
                let cell = allDayEventsView.cellForItem(at: path) as? EventCell
            {
                //                if eventType { &eventType = .allDay }
                //                if index { &index = path.item }
                //                if date { &date = self.date(fromDayOffset: path.section) }
                return cell.eventView
            }
        }
        return nil
    }

    func eventView(
        _ eventType: EventType,
        at index: Int,
        date: Date
    ) -> EventView? {
        let section = dayOffset(from: date)
        let indexPath = IndexPath(item: index, section: section)
        let cell = collectionViewCell(for: eventType, at: indexPath)
        return cell?.eventView
    }

    func selectEvent(
        of eventType: EventType,
        at index: Int,
        date: Date
    ) {
        selectEvent(
            tellDelegate: false,
            eventType: eventType,
            at: index,
            date: date
        )
    }

    func selectEvent(
        tellDelegate: Bool,
        eventType: EventType,
        at index: Int,
        date: Date
    ) {
        deselectEvent(tellDelegate: tellDelegate)

        guard allowsSelection else { return }

        let section = dayOffset(from: date)

        let path = IndexPath(item: index, section: section)

        guard let cell = collectionViewCell(for: eventType, at: path) else { return }

        var shouldSelect = true

        if tellDelegate, let delegate {
            shouldSelect = delegate.dayPlanView(
                self,
                shouldSelectEventOfType: eventType,
                at: index,
                date: date
            )
        }

        guard shouldSelect else { return }

        cell.isSelected = true
        selectedCellIndexPath = path
        selectedCellType = eventType

        guard tellDelegate else { return }

        delegate?
            .dayPlanView(
                self,
                didSelectEventOfType: eventType,
                at: path.item,
                date: date
            )
    }

    func deselectEvent() {
        deselectEvent(tellDelegate: false)
    }

    func reloadAllEvents() {
        deselectEvent(tellDelegate: true)

        allDayEventsView.reloadData()
        timedEventsView.reloadData()

        if controllingScrollView == nil {
            DispatchQueue.main.async(execute: setupSubviews)
        }

        loadedDaysRange.enumerateDays(with: calendar) { date, stop in
            refreshEventMarkForColumn(at: date)
        }
    }

    func reloadEvents(at date: Date) {
        deselectEvent(tellDelegate: true)

        guard loadedDaysRange.contains(date) else { return }

        allDayEventsView.reloadData()

        if controllingScrollView == nil {
            setupSubviews()
        }

        timedEventsViewLayout.ignoreNextInvalidation = true
        timedEventsView.reloadData()

        let section = dayOffset(from: date)

        let context = TimedEventsViewLayoutInvalidationContext()
        context.invalidatedSections = IndexSet(integer: section)
        timedEventsView.collectionViewLayout.invalidateLayout(with: context)

        refreshEventMarkForColumn(at: date)
    }

    func insert(eventOfType: EventType, dateRange: DateRange) {
        let start = max(dayOffset(from: dateRange.start), 0)
        let end = min(dayOffset(from: dateRange.end), numberOfLoadedDays)

        var indexPaths: [IndexPath] = []

        for section in start...end {
            let date = date(fromDayOffset: section)
            if let dataSource {
                let num = dataSource.dayPlanView(
                    self,
                    numberOfEventsOfType: eventOfType,
                    at: date
                )
                let path = IndexPath(item: num, section: section)
                indexPaths.append(path)
            }
        }

        switch eventOfType {
        case .allDay:
            allDayEventsView.insertItems(at: indexPaths)
        case .timed:
            timedEventsView.insertItems(at: indexPaths)
        }
    }

    func setActivityIndicator(visible: Bool, for date: Date) -> Bool {
        if visible {
            loadingDays.append(date)
        } else {
            loadingDays.remove(date)
        }

        guard loadedDaysRange.contains(date) else { return false }
        let section = dayOffset(from: date)
        let path = IndexPath(item: 0, section: section)
        if let cell = dayColumnsView.cellForItem(at: path) as? DayColumnCell {
            //            cell.activityIndicator(visible: visible)
            return true
        }
        return false
    }

    func endInteraction() {
        interactiveCell?.isHidden = true
        interactiveCell?.removeFromSuperview()
        interactiveCell = nil

        dragTimer?.invalidate()
        dragTimer = nil

        interactiveCellTouchPoint = .zero
        timeRowsView.timeMark = 0
    }

    func reloadDimmedTimeRanges() {
        dimmedTimeRangesCache.removeAll()

        let context = TimedEventsViewLayoutInvalidationContext()
        context.invalidatedSections = IndexSet(integersIn: 0..<numberOfLoadedDays)
        context.invalidateEventCells = false
        context.invalidateDimmingViews = true
        timedEventsView.collectionViewLayout.invalidateLayout(with: context)
    }

    /// this is called whenever we recenter the views during scrolling
    /// or when the number of visible days or the date range changes
    private func reloadCollectionViews() {
        deselectEvent(tellDelegate: true)

        let dayColumnSize = dayColumnSize

        timedEventsViewLayout.dayColumnSize = dayColumnSize
        allDayEventsViewLayout.dayColumnWidth = dayColumnSize.width
        allDayEventsViewLayout.eventCellHeight = allDayEventCellHeight

        dayColumnsView.reloadData()
        timedEventsView.reloadData()
        allDayEventsView.reloadData()

        if controllingScrollView == nil {  // only if we're not scrolling
            DispatchQueue.main.async(execute: setupSubviews)
        }
    }

    private func deselectEvent(tellDelegate: Bool) {
        guard
            allowsSelection,
            let selectedCellIndexPath,
            let selectedCellType
        else { return }

        let cell = collectionViewCell(for: selectedCellType, at: selectedCellIndexPath)
        cell?.isSelected = false

        let date = date(fromDayOffset: selectedCellIndexPath.section)

        if tellDelegate {
            delegate?
                .dayPlanView(
                    self,
                    didDeselectEventOfType: selectedCellType,
                    at: selectedCellIndexPath.item,
                    date: date
                )
        }

        self.selectedCellIndexPath = nil
        self.selectedCellType = nil  // DB
    }

    private func refreshEventMarkForColumn(at date: Date) {
        let section = dayOffset(from: date)
        let indexPath = IndexPath(item: 0, section: section)

        guard let cell = dayColumnsView.cellForItem(at: indexPath) as? DayColumnCell
        else { return }

        let count = numberOfAllDayEvents(at: date) + numberOfTimedEvents(at: date)

        if count > 0 {
            cell.accessoryTypes.insert(.dot)
        } else {
            cell.accessoryTypes.remove(.dot)
        }
    }

    private func collectionViewCell(
        for eventType: EventType,
        at indexPath: IndexPath
    ) -> EventCell? {
        switch eventType {
        case .allDay:
            return allDayEventsView.cellForItem(at: indexPath) as? EventCell
        case .timed:
            return timedEventsView.cellForItem(at: indexPath) as? EventCell
        }
    }

    private func time(fromYOffset yOffset: CGFloat, rounding: Int) -> TimeInterval {
        let rounding = max(rounding % 60, 1)
        let hour =
            fmax(
                0,
                (yOffset - eventsViewInnerMargin) / hourSlotHeight
            ) + CGFloat(hourRange.location)

        return round((hour * 3600) / (CGFloat(rounding) * 60)) * (CGFloat(rounding) * 60)
    }

    private func offset(from time: TimeInterval, rounding: Int) -> CGFloat {
        let rounding = max(rounding % 60, 1)
        let time = round(time / Double(rounding * 60)) * Double(rounding * 60)
        let hour = time / 3600 - Double(hourRange.location)
        return (hour * hourSlotHeight + eventsViewInnerMargin).aligned
    }

    private func offset(from date: Date, eventType: EventType) -> CGPoint {
        let x = xOffset(fromDayOffset: dayOffset(from: date))

        switch eventType {
        case .allDay:
            return convert(.init(x: x, y: 0), from: allDayEventsView)
        case .timed:
            let time = date.timeIntervalSince(calendar.startOfDay(for: date))
            let y = offset(from: time, rounding: 1)
            return convert(.init(x: x, y: y), from: timedEventsView)
        }
    }

    private func offset(from date: Date) -> CGFloat {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let hours = comps.hour! + comps.minute! / 60 - hourRange.location
        let y = round(CGFloat(hours) * hourSlotHeight + eventsViewInnerMargin)
        return y.aligned
    }

    private func xOffset(fromDayOffset offset: Int) -> CGFloat {
        dayColumnSize.width * CGFloat(offset)
    }

    /// returns the day offset from the first loaded day in the view (ie startDate)
    private func dayOffset(from date: Date) -> Int {
        calendar.dateComponents([.day], from: startDate, to: date).day!
    }

    private func date(fromDayOffset offset: Int) -> Date {
        calendar.date(byAdding: .init(day: offset), to: startDate)!
    }

    /// returns the latest date to be shown on the left side of the view,
    /// nil if the day planner has no date range.
    private var maxScrollableDate: Date? {
        guard let dateRange else { return nil }
        let numVisible = min(
            numberOfVisibleDays,
            dateRange.components(unitFlags: [.day], for: calendar).day!
        )
        return calendar.date(
            byAdding: DateComponents(day: -numVisible),
            to: dateRange.end
        )
    }

    /// retuns the earliest date to be shown on the left side of the view,
    /// nil if the day planner has no date range.
    private var minScrollableDate: Date? {
        dateRange?.start
    }

    /// this is the entry point for every programmatic scrolling of the timed events view
    private func setTimedEventsView(
        contentOffset offset: CGPoint,
        animated: Bool,
        completion: @escaping () -> Void
    ) {
        guard controllingScrollView == nil else { return }

        let prevOffset = timedEventsView.contentOffset

        if animated, offset != prevOffset {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }

        scrollViewAnimationCompletionBlock = completion

        scrollView(timedEventsView, willStartScrollingOnDirection: .unknown)
        timedEventsView.setContentOffset(offset, animated: animated)

        if !animated || offset == prevOffset {
            scrollViewDidEndScrolling(timedEventsView)
        }
    }

    private func recenterIfNeeded() -> Bool {
        guard let controllingScrollView else {
            assertionFailure("Trying to recenter with no controlling scroll view")
            return false
        }

        let xOffset = controllingScrollView.contentOffset.x
        let xContentSize = controllingScrollView.contentSize.width
        let xPageSize = controllingScrollView.bounds.size.width

        // This could eventually be tweaked - for now we recenter when we have less than a page on one or the other side
        if xOffset < xPageSize || xOffset + 2 * xPageSize > xContentSize {

            var aOffset: Int?
            let newStart = startDateForFirstVisibleDate(
                visibleDays.start,
                dayOffset: &aOffset
            )
            let diff =
                calendar.dateComponents(
                    [.day],
                    from: startDate,
                    to: newStart
                )
                .day!

            if diff != 0 {
                startDate = newStart
                reloadCollectionViews()

                let newXOffset =
                    -CGFloat(diff) * dayColumnSize.width + controllingScrollView.contentOffset.x

                controllingScrollView.contentOffset = CGPoint(
                    x: newXOffset,
                    y: controllingScrollView.contentOffset.y
                )
                return true
            }
        }
        return false
    }

    private func startDateForFirstVisibleDate(
        _ date: Date,
        dayOffset offset: inout Int?
    ) -> Date {
        let date = calendar.startOfDay(for: date)

        var comps = DateComponents()
        comps.day = -daysLoadingStep * numberOfVisibleDays
        var start = calendar.date(byAdding: comps, to: date)!

        // Stay within the limits of our date range
        if let dateRange, start.compare(dateRange.start) == .orderedAscending {
            start = dateRange.start
        } else if let maxStartDate, start.compare(maxStartDate) == .orderedDescending {
            start = maxStartDate
        }

        if offset != nil {
            offset = abs(calendar.dateComponents([.day], from: start, to: date).day!)
        }

        return start
    }

    private func scrollView(
        _ scrollView: UIScrollView,
        willStartScrollingOnDirection direction: ScrollDirection
    ) {
        assert(
            scrollView == timedEventsView || scrollView == allDayEventsView,
            "For synchronizing purposes, only timedEventsView or allDayEventsView are allowed to scroll"
        )

        if let controllingScrollView {
            assert(
                scrollView == controllingScrollView,
                "Scrolling on two different views at the same time is not allowed"
            )
        }

        guard controllingScrollView == nil else { return }

        if scrollView == timedEventsView {
            allDayEventsView.isScrollEnabled = false
        } else if scrollView == allDayEventsView {
            timedEventsView.isScrollEnabled = false
        }

        controllingScrollView = scrollView
        scrollStartOffset = scrollView.contentOffset
        scrollDirection = direction
    }

    /// this is called at the end of every scrolling operation, initiated by user or programatically
    func scrollViewDidEndScrolling(_ scrollView: UIScrollView) {
        // reset everything
        guard scrollView == controllingScrollView else { return }

        let direction = scrollDirection

        scrollDirection = .unknown
        timedEventsView.isScrollEnabled = true
        allDayEventsView.isScrollEnabled = true
        controllingScrollView = nil

        if let completion = scrollViewAnimationCompletionBlock {
            DispatchQueue.main.async(execute: completion)
            scrollViewAnimationCompletionBlock = nil
        }

        if direction == .horizontal {
            setupSubviews()  // allDayEventsView might need to be resized
        }

        delegate?
            .dayPlanView(
                self,
                didEndScrolling: direction == .horizontal ? .date : .time
            )
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == controllingScrollView else { return }

        lockScrollingDirection()

        if scrollDirection.contains(.horizontal) {
            recenterIfNeeded()
        }

        synchronizeScrolling()

        updateVisibleDaysRange()

        delegate?
            .dayPlanView(
                self,
                didScroll: scrollDirection.contains(.horizontal)
                    ? .date : .time
            )
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.scrollView(scrollView, willStartScrollingOnDirection: .unknown)
    }

    public func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        guard scrollDirection.contains(.horizontal) else { return }

        var xOffset = targetContentOffset.pointee.x

        if abs(velocity.x) < 0.7 || !pagingEnabled {
            // Stick to nearest section
            let section = round(xOffset / dayColumnSize.width)
            xOffset = section * dayColumnSize.width
            self.scrollTargetDate = date(fromDayOffset: Int(section))
        } else if pagingEnabled {
            var date: Date

            // Scroll to next page
            if velocity.x > 0 {
                date = nextDate(forPagingAfter: visibleDays.start)
            }
            // Scroll to previous page
            else {
                date = previousDate(forPagingBefore: firstVisibleDate)
            }

            let section = dayOffset(from: date)
            xOffset = self.xOffset(fromDayOffset: section)
            scrollTargetDate = self.date(fromDayOffset: section)
        }

        xOffset = min(
            max(xOffset, 0),
            scrollView.contentSize.width - scrollView.bounds.width
        )
        targetContentOffset.pointee.x = xOffset
    }

    public func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        if !decelerate, !scrollView.isDecelerating {
            scrollViewDidEndScrolling(scrollView)
        }

        if decelerate {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollViewDidEndScrolling(scrollView)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollViewDidEndScrolling(scrollView)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    private func lockScrollingDirection() {
        guard let controllingScrollView else {
            fatalError("Trying to lock scrolling direction while no scroll operation has started")
        }

        let contentOffset = controllingScrollView.contentOffset

        if scrollDirection == .unknown {
            // Determine direction
            if abs(scrollStartOffset.x - contentOffset.x)
                < abs(scrollStartOffset.y - contentOffset.y)
            {
                scrollDirection = .vertical
            } else {
                scrollDirection = .horizontal
            }
        }

        // Lock scroll position of the scroll view according to detected direction
        if scrollDirection.contains(.vertical) {
            controllingScrollView.contentOffset = CGPoint(
                x: scrollStartOffset.x,
                y: contentOffset.y
            )

        } else if scrollDirection.contains(.horizontal) {
            controllingScrollView.contentOffset = CGPoint(
                x: contentOffset.x,
                y: scrollStartOffset.y
            )
        }
    }

    private func synchronizeScrolling() {
        guard let controllingScrollView else {
            assertionFailure("Synchronizing scrolling with no controlling scroll view")
            return
        }

        let contentOffset = controllingScrollView.contentOffset

        if controllingScrollView == allDayEventsView, scrollDirection.contains(.horizontal) {
            dayColumnsView.contentOffset = CGPoint(x: contentOffset.x, y: 0)
            timedEventsView.contentOffset = CGPoint(
                x: contentOffset.x,
                y: timedEventsView.contentOffset.y
            )
        } else if controllingScrollView == timedEventsView {
            if scrollDirection.contains(.horizontal) {
                dayColumnsView.contentOffset = CGPoint(x: contentOffset.x, y: 0)
                allDayEventsView.contentOffset = CGPoint(
                    x: contentOffset.x,
                    y: allDayEventsView.contentOffset.y
                )
            } else {
                timeScrollView.contentOffset = CGPoint(x: 0, y: contentOffset.y)
            }
        }
    }

    private func nextDate(forPagingAfter date: Date) -> Date {
        var nextDate: Date

        if numberOfVisibleDays >= 7 {
            nextDate = calendar.nextStartOfWeek(for: date)
        } else {
            nextDate = calendar.date(
                byAdding: DateComponents(day: numberOfVisibleDays),
                to: date
            )!
        }

        if let maxScrollableDate, nextDate > maxScrollableDate {
            nextDate = maxScrollableDate
        }

        return nextDate
    }

    private func previousDate(forPagingBefore date: Date) -> Date {
        var prevDate: Date

        if numberOfVisibleDays >= 7 {
            prevDate = calendar.startOfWeek(for: date)
            if prevDate == date {
                prevDate = calendar.date(
                    byAdding: DateComponents(day: -7),
                    to: date
                )!
            }
        } else {
            prevDate = calendar.date(
                byAdding: DateComponents(day: -numberOfVisibleDays),
                to: date
            )!
        }

        if let minScrollableDate, prevDate < minScrollableDate {
            prevDate = minScrollableDate
        }

        return prevDate
    }

    private func scrollableTimeRange(for date: Date) -> DateRange {
        let start = calendar.date(
            bySettingHour: hourRange.location,
            minute: 0,
            second: 0,
            of: date
        )!
        let end = calendar.date(
            bySettingHour: NSMaxRange(hourRange) - 1,
            minute: 59,
            second: 0,
            of: date
        )!
        return .init(start: start, end: end)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension DayPlanView: UICollectionViewDelegateFlowLayout {

    public func collectionView(
        _ collectionView: UICollectionView,
        targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint
    ) -> CGPoint {
        var proposedContentOffset = proposedContentOffset
        if let scrollTargetDate {
            let section = dayOffset(from: scrollTargetDate)
            proposedContentOffset.x = CGFloat(section) * dayColumnSize.width
        }
        return proposedContentOffset
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        .init(width: dayColumnSize.width, height: bounds.height)
    }
}

// MARK: - UICollectionViewDataSource
extension DayPlanView: UICollectionViewDataSource {

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        numberOfLoadedDays
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        if collectionView == timedEventsView {
            let date = date(fromDayOffset: section)
            return dataSource?
                .dayPlanView(
                    self,
                    numberOfEventsOfType: .timed,
                    at: date
                ) ?? 0
        } else if collectionView == allDayEventsView {
            guard showsAllDayEvents else { return 0 }
            let date = date(fromDayOffset: section)
            let count =
                dataSource?
                .dayPlanView(
                    self,
                    numberOfEventsOfType: .allDay,
                    at: date
                ) ?? 0
            print("date: \(date) count: \(count)")
            return count
        }
        return 1  // for dayColumnView
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        if collectionView == timedEventsView {
            return dequeueCell(for: .timed, at: indexPath)
        }
        if collectionView == allDayEventsView {
            return dequeueCell(for: .allDay, at: indexPath)
        }
        if collectionView == dayColumnsView {
            return dayColumnCell(at: indexPath)
        }
        fatalError("no cell")
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {

        if kind == ReusableConstants.Kind.dimmingView {
            let view = timedEventsView.dequeueReusableSupplementaryView(
                ofKind: ReusableConstants.Kind.dimmingView,
                withReuseIdentifier: ReusableConstants.Identifier.dimmingView,
                for: indexPath
            )
            view.backgroundColor = dimmingColor
            return view
        } else if kind == ReusableConstants.Kind.moreEvents {
            let view = allDayEventsView.dequeueReusableSupplementaryView(
                ofKind: ReusableConstants.Kind.moreEvents,
                withReuseIdentifier: ReusableConstants.Identifier.moreEventsView,
                for: indexPath
            )

            view.autoresizesSubviews = true

            let hiddenCount = allDayEventsViewLayout.numberOfHiddenEvents(in: indexPath.section)
            let label = UILabel(frame: view.bounds)
            label.text = "\(hiddenCount) more..."
            label.textColor = .black
            label.font = UIFont.systemFont(ofSize: 11)
            label.autoresizingMask = [.flexibleHeight, .flexibleWidth]

            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(label)

            return view
        }
        return UICollectionReusableView()
    }

    private func dequeueCell(
        for eventType: EventType,
        at indexPath: IndexPath
    ) -> UICollectionViewCell {

        let date = date(fromDayOffset: indexPath.section)
        let index = indexPath.item
        let eventView = dataSource?
            .dayPlanView(
                self,
                viewForEventOfType: eventType,
                at: index,
                date: date
            )

        let eventCell: EventCell

        switch eventType {
        case .allDay:
            eventCell = allDayEventsView.dequeueReusableCell(
                for: indexPath,
                cellType: EventCell.self
            )
        case .timed:
            eventCell = timedEventsView.dequeueReusableCell(
                for: indexPath,
                cellType: EventCell.self
            )
        }

        eventCell.eventView = eventView

        if let selectedCellIndexPath,
            selectedCellIndexPath == indexPath,
            let selectedCellType,
            selectedCellType == eventType
        {
            eventCell.isSelected = true
        }

        return eventCell
    }

    private func dayColumnCell(at indexPath: IndexPath) -> UICollectionViewCell {
        let dayCell = dayColumnsView.dequeueReusableCell(
            for: indexPath,
            cellType: DayColumnCell.self
        )

        dayCell.headerHeight = dayHeaderHeight
        dayCell.separatorColor = daySeparatorsColor

        let date = date(fromDayOffset: indexPath.section)
        let weekDay = calendar.component(.weekday, from: date)
        var accessoryTypes: DayColumnCellAccessoryType =
            weekDay == calendar.firstWeekday ? .separator : .border

        dayCell.dayHeader.date = date

        if calendar.isDate(date, sameDayAs: Date()) {
            accessoryTypes.insert(.mark)
            dayCell.markColor = tintColor
        }

        let count = numberOfAllDayEvents(at: date) + numberOfTimedEvents(at: date)
        if count > 0 {
            accessoryTypes.insert(.dot)
        }

        dayCell.accessoryTypes = accessoryTypes
        return dayCell
    }
}

// MARK: - TimedEventsViewLayoutDelegate
extension DayPlanView: TimedEventsViewLayoutDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        layout: TimedEventsViewLayout,
        rectForEventAt indexPath: IndexPath
    ) -> CGRect {
        let date = date(fromDayOffset: indexPath.section)

        let dayRange = scrollableTimeRange(for: date)

        guard
            let eventRange = dataSource?
                .dayPlanView(
                    self,
                    dateRangeForEventOfType: .timed,
                    at: indexPath.item,
                    date: date
                )
        else {
            return .null
        }

        eventRange.intersect(dayRange)

        guard !eventRange.isEmpty else { return .null }

        let y1 = offset(from: eventRange.start)
        let y2 = offset(from: eventRange.end)

        return CGRect(x: 0, y: y1, width: 0, height: y2 - y1)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: TimedEventsViewLayout,
        dimmingRectsFor section: Int
    ) -> [CGRect] {

        let date = date(fromDayOffset: section)

        if let ranges = try? dimmedTimeRangesCache.object(forKey: date) {
            return rects(from: ranges)
        } else {
            let ranges = dimmedTimeRanges(at: date)
            dimmedTimeRangesCache.setObject(ranges, forKey: date)
            return rects(from: ranges)
        }

        func rects(from ranges: [DateRange]) -> [CGRect] {
            ranges.compactMap { range -> CGRect? in
                guard !range.isEmpty else { return nil }
                let y1 = offset(from: range.start)
                let y2 = offset(from: range.end)
                return CGRect(x: 0, y: y1, width: 0, height: y2 - y1)
            }
        }
    }

    private func dimmedTimeRanges(at date: Date) -> [DateRange] {
        guard let delegate else { return [] }

        let count = delegate.dayPlanView(self, numberOfDimmedTimeRangesAt: date)

        guard count > 0 else { return [] }

        let dayRange = scrollableTimeRange(for: date)

        var ranges: [DateRange] = []

        for i in 0..<count {
            if let range = delegate.dayPlanView(
                self,
                dimmedTimeRangeAt: i,
                date: date
            ) {
                range.intersect(dayRange)

                if !range.isEmpty {
                    ranges.append(range)
                }
            }
        }

        return ranges
    }
}

// MARK: - AllDayEventViewLayoutDelegate
extension DayPlanView: AllDayEventViewLayoutDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        layout: AllDayEventsViewLayout,
        dayRangeForEventAt indexPath: IndexPath
    ) -> NSRange? {

        let date = date(fromDayOffset: indexPath.section)

        guard
            let dataSource,
            let dateRange =
                dataSource
                .dayPlanView(
                    self,
                    dateRangeForEventOfType: .allDay,
                    at: indexPath.item,
                    date: date
                )
        else {
            fatalError(
                "[AllDayEventsViewLayoutDelegate dayPlannerView:dateRangeForEventOfType:atIndex:date:] cannot return nil!"
            )
        }

        if dateRange.start.compare(startDate) == .orderedAscending {
            dateRange.start = startDate
        }

        let startSection = dayOffset(from: dateRange.start)
        let length =
            calendar.dateComponents(
                [.day],
                from: dateRange.start,
                to: dateRange.end
            )
            .day!

        return NSRange(location: startSection, length: length)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: AllDayEventsViewLayout,
        insetsForEventAt indexPath: IndexPath
    ) -> AllDayEventInset {
        .none
        // TODO: implement
    }
}

// MARK: - AllDayEventViewLayoutDelegate
extension DayPlanView: TimeRowsViewDelegate {

    func timeRowsView(
        _ timeRowsView: TimeRowsView,
        attributedStringFor timeMark: DayPlanTimeMark,
        time: TimeInterval
    ) -> NSAttributedString? {
        delegate?
            .dayPlanView(
                self,
                attributedStringForTimeMark: timeMark,
                time: time
            )
    }
}
