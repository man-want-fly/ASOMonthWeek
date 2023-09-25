//
//  MonthPlanView.swift
//  CalLib
//
//  Created by mwf on 2023/8/12.
//

import OrderedCollections
import Reusable
import UIKit

struct MonthPlanGridStyle: OptionSet {
    let rawValue: Int

    static let fill = MonthPlanGridStyle(rawValue: 1 << 0)
    static let verticalLines = MonthPlanGridStyle(rawValue: 1 << 1)
    static let horizontalLines = MonthPlanGridStyle(rawValue: 1 << 2)
    static let bottomDayLabel = MonthPlanGridStyle(rawValue: 1 << 3)
    static let `default`: MonthPlanGridStyle = [verticalLines, horizontalLines]
}

enum CalendarViewScrollingDirection: Int {
    case up = 0
    case down
}

private let dragScrollOffset: CGFloat = 20
private let dragScrollZoneSize: CGFloat = 20
private let defaultDateFormat = "dMMYY"
private let rowCacheSize = 40

public class MonthPlanView: UIView {

    public var calendar: Calendar = .current

    public lazy var currentDisplayingMonthDate: Date = .init() {
        didSet {
            guard oldValue != currentDisplayingMonthDate else { return }
            delegate?.monthPlanView(self, didDisplayMonthAt: currentDisplayingMonthDate)
        }
    }

    var headerHeight: CGFloat = 35

    var dayCellHeaderHeight: CGFloat = 24 {
        didSet {
            layout.dayHeaderHeight = dayCellHeaderHeight
            eventsView.reloadData()
        }
    }

    var monthInsets: UIEdgeInsets = .zero {
        didSet {
            guard monthInsets != oldValue else { return }
            //            layout.monthInsets = monthInsets
            setNeedsLayout()
        }
    }

    var gridStyle: MonthPlanGridStyle = [.fill, .default] {
        didSet {
            guard gridStyle != oldValue else { return }
            eventsView.reloadData()
        }
    }

    public var dateFormat: String?  // use default
    {
        set {
            dateFormatter.dateFormat = newValue ?? defaultDateFormat
            eventsView.reloadData()
        }
        get {
            dateFormatter.dateFormat
        }
    }

    public var itemHeight: CGFloat = 16

    public var calendarBackgroundColor: UIColor = .systemBackground
    public var weekDayBackgroundColor: UIColor = .systemGroupedBackground
    public var weekendDayBackgroundColor: UIColor = .tertiarySystemGroupedBackground

    public var monthLabelTextColor: UIColor = .label

    public var monthLabelFont: UIFont = UIFont.preferredFont(forTextStyle: .headline)

    public var canCreateEvents: Bool = true

    public var canMoveEvents: Bool = true

    public weak var dataSource: MonthPlanViewDataSource?
    public weak var delegate: MonthPlanViewDelegate?

    public var dateRange: DateRange? {
        didSet {
            guard let dateRange, let visibleDays = visibleDays() else { return }

            var firstDate = visibleDays.start

            if !dateRange.includes(loadedDateRange) {
                startDate = dateRange.start
            }

            if !dateRange.contains(firstDate) {
                firstDate = Date()

                if !dateRange.contains(firstDate) {
                    firstDate = dateRange.start
                }
            }

            eventsView.reloadData()
            scrollTo(date: firstDate, animated: false)
        }
    }

    func register(cellClass: AnyClass, forEventCellWithReuseIdentifier reuseIdentifier: String) {
        reuseQueue.register(cellClass, forObjectWithReuseIdentifier: reuseIdentifier)
    }

    func dequeueReusableCell(
        withReuseIdentifier reuseIdentifier: String,
        forEventAt index: Int,
        date: Date
    ) -> EventView? {
        guard let cell = reuseQueue.dequeue(by: reuseIdentifier) as? EventView else { return nil }

        if selectedEventDate == date && index == selectedEventIndex {
            cell.selected = true
        }

        return cell
    }

    public func scrollTo(date: Date, animated: Bool) {
        // check if date in range
        if let dateRange, !dateRange.contains(date) {
            fatalError(
                "Invalid parameter"
                    + "date \(date) is not in range \(dateRange) for this month planner view"
            )
        }

        //        var yOffset = yOffsetForMonth(date)
        let xOffset = xOffsetForMonth(date)

        //        if alignment == .headerBottom {
        //            yOffset += monthInsets.top
        //        } else if alignment == .weekRow {
        //            let weekNum = calendar.indexOfWeekInMonth(for: date)
        //            yOffset += monthInsets.top + CGFloat((weekNum - 1)) * rowHeight
        //        }

        eventsView.setContentOffset(CGPoint(x: xOffset, y: 0), animated: animated)

        delegate?.monthPlanViewDidScroll(self)
    }

    // adjusts startDate so that month at given date is centered.
    // returns the distance in months between old and new start date
    private func adjustStartDateForCenteredMonthDate(_ date: Date) -> Int {
        let contentWidth = eventsView.contentSize.width
        let boundsWidth = eventsView.bounds.width

        let offset = Int(floor((contentWidth - boundsWidth) / monthMaximumWidth) / 2)

        guard
            var start = calendar.date(
                byAdding: .month,
                value: -offset,
                to: date
            )
        else { return 0 }

        if let dateRange, start < dateRange.start {
            start = dateRange.start
        } else if let maxStartDate, start > maxStartDate {
            start = maxStartDate
        }

        let diff =
            calendar.dateComponents(
                [.month],
                from: startDate,
                to: start
            )
            .month ?? 0

        startDate = start
        return diff
    }

    // returns YES if the collection view was reloaded
    private func recenterIfNeeded() -> Bool {
        let xOffset = eventsView.contentOffset.x
        let contentWidth = eventsView.contentSize.width

        if xOffset < monthMaximumWidth
            || eventsView.bounds.maxX + monthMaximumWidth > contentWidth
        {
            let oldStart = startDate

            let centerMonth = monthFromXOffset(xOffset)
            let monthOffset = adjustStartDateForCenteredMonthDate(centerMonth)

            if monthOffset != 0 {
                let x = xOffsetForMonth(oldStart)

                eventsView.reloadData()

                var offset = eventsView.contentOffset
                offset.x = x + xOffset
                eventsView.contentOffset = offset

                return true
            }
        }
        return false
    }

    func visibleDays() -> DateRange? {
        eventsView.layoutIfNeeded()

        var range: DateRange?

        let visible = eventsView.indexPathsForVisibleItems.sorted(by: <)
        if !visible.isEmpty {
            let first = dateForDay(at: visible.first!)
            let last = dateForDay(at: visible.last!)

            let lastDate = calendar.date(byAdding: .day, value: 1, to: last)!

            range = DateRange(start: first, end: lastDate)
        }
        return range
    }

    func visibleEventCells() -> [EventView] {
        var cells: [EventView] = []

        for rowView in visibleEventRows() {
            let rect = rowView.convert(bounds, from: self)
            cells.append(contentsOf: rowView.cells(in: rect))
        }

        return cells
    }

    func cellForEvent(at index: Int, date: Date) -> EventView? {
        for rowView in visibleEventRows() {
            let day =
                calendar.dateComponents(
                    [.day],
                    from: rowView.referenceDate!,
                    to: date
                )
                .day!

            if NSLocationInRange(day, rowView.daysRange) {
                return rowView.cell(at: IndexPath(item: index, section: day))
            }
        }
        return nil
    }

    func eventCell(at point: CGPoint, date: inout Date?, index: inout Int) -> EventView? {
        for rowView in visibleEventRows() {
            let ptInRow = rowView.convert(point, from: self)
            if let path = rowView.indexPathForCell(at: ptInRow) {
                var comps = DateComponents()
                comps.day = path.section
                date = calendar.date(byAdding: comps, to: rowView.referenceDate!)
                index = path.item
                return rowView.cell(at: path)
            }
        }
        return nil
    }

    func day(at pt: CGPoint) -> Date? {
        let convertedPoint = eventsView.convert(pt, from: self)
        if let path = eventsView.indexPathForItem(at: convertedPoint) {
            return dateForDay(at: path)
        }
        return nil
    }

    func reloadEvents() {
        deselectEvent(tellDelegate: true)

        let visibleDateRange = visibleDays()

        eventRows.forEach { date, rowView in
            let rowRange = dateRange(for: rowView)

            if let rowRange, let visibleDateRange, rowRange.intersects(visibleDateRange) {
                rowView.reload()
            } else {
                removeRow(at: date)
            }
        }
    }

    func reloadEvents(at date: Date) {
        if selectedEventDate == date {
            deselectEvent(tellDelegate: true)
        }

        let visibleDateRange = visibleDays()
        eventRows.forEach { date, rowView in
            let rowRange = dateRange(for: rowView)

            if let rowRange, rowRange.contains(date) {
                if let visibleDateRange, visibleDateRange.contains(date) {
                    rowView.reload()
                } else {
                    removeRow(at: date)
                }
            }
        }
    }

    func reloadEvents(in dateRange: DateRange) {
        if let selectedEventDate, dateRange.contains(selectedEventDate) {
            deselectEvent(tellDelegate: true)
        }

        guard let visibleDateRange = visibleDays() else { return }

        eventRows.keys.forEach { date in
            if let rowView = eventRows[date],
                let rowRange = self.dateRange(for: rowView),
                rowRange.intersects(dateRange)
            {
                if rowRange.intersects(visibleDateRange) {
                    rowView.reload()
                } else {
                    removeRow(at: date)
                }
            }
        }
    }

    var allowSelection: Bool = true

    var selectedEventDate: Date?

    var selectedEventIndex: Int?

    var selectedEventView: EventView?

    func selectEventCell(at index: Int, date: Date) {
        deselectEvent(tellDelegate: false)

        guard allowSelection else { return }

        let cell = cellForEvent(at: index, date: date)
        cell?.selected = true

        selectedEventDate = date
        selectedEventIndex = index
    }

    func deselectEvent() {
        if allowSelection {
            deselectEvent(tellDelegate: false)
        }
    }

    func endInteraction() {
        if let interactiveCell {
            interactiveCell.isHidden = true
            interactiveCell.removeFromSuperview()
            self.interactiveCell = nil
        }
        interactiveCellTouchPoint = .zero

        dragEventDateRange = nil
        dragEventDate = nil
        dragEventIndex = -1
        dragEventTouchDayOffset = 0

        highlightDays(in: nil)
    }

    // --------------------------------------------------------------------------

    private lazy var eventsView: UICollectionView = {
        let layout = MonthPlanViewLayout()
        layout.dayHeaderHeight = dayCellHeaderHeight
        layout.delegate = self
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.scrollsToTop = false
        collectionView.contentInsetAdjustmentBehavior = .never

        collectionView.register(cellType: MonthPlanViewDayCell.self)

        collectionView.register(
            MonthPlanBackgroundView.self,
            forSupplementaryViewOfKind: ReusableConstants.Kind.monthBackground,
            withReuseIdentifier: ReusableConstants.Identifier.monthBackgroundView
        )
        collectionView.register(
            MonthPlanWeekView.self,
            forSupplementaryViewOfKind: ReusableConstants.Kind.monthRow,
            withReuseIdentifier: ReusableConstants.Identifier.monthRowView
        )
        collectionView.register(
            MonthPlanMonthHeaderView.self,
            forSupplementaryViewOfKind: ReusableConstants.Kind.monthHeader,
            withReuseIdentifier: ReusableConstants.Identifier.monthHeaderView
        )

        let longPressGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        collectionView.addGestureRecognizer(longPressGesture)
        return collectionView
    }()

    private var layout: MonthPlanViewLayout {
        eventsView.collectionViewLayout as! MonthPlanViewLayout
    }

    private var _startDate: Date?

    private var startDate: Date {
        set {
            print("startDate--set: \(newValue)")
            //            var date = newValue
            //            date = calendar.startOfMonth(for: newValue)
            ////            assert(
            ////                startDate.compare(dateRange!.start) != .orderedAscending,
            ////                "start date not in the scrollable date range"
            ////            )
            ////            assert(
            ////                startDate.compare(maxStartDate!) != .orderedDescending,
            ////                "start date not in the scrollable date range"
            ////            )
            ////            self.startDate = date
            _startDate = calendar.startOfMonth(for: newValue)
        }
        get {
            if let _startDate {
                return _startDate
            } else {
                _startDate = calendar.startOfMonth(for: Date())
                if let dateRange, let _date = _startDate, !dateRange.contains(_date) {
                    _startDate = dateRange.start
                }
                return _startDate!
            }
        }
    }

    private var maxStartDate: Date? {
        var date: Date?
        if let dateRange {
            let components = DateComponents(month: -numberOfLoadedMonths)
            date = calendar.date(byAdding: components, to: dateRange.end)
            if var date, date < dateRange.start {
                date = dateRange.start
            }
        }
        return date
    }

    /// number of months loaded at once in the collection view
    private var numberOfLoadedMonths: Int {
        var numMonths = 9
        let minContentHeight = eventsView.bounds.width + 2 * monthMaximumWidth

        let minLoadedMonths = 3  //ceilf(Float(minContentHeight / monthMinimumWidth))

        numMonths = max(numMonths, minLoadedMonths)

        if let dateRange = self.dateRange {
            let diff = dateRange.components(unitFlags: [.month], for: calendar).month!
            numMonths = min(numMonths, diff)
        }

        return numMonths
    }

    private var loadedDateRange: DateRange {
        let components = DateComponents(month: numberOfLoadedMonths)
        let end = calendar.date(byAdding: components, to: startDate)!
        return .init(start: startDate, end: end)
    }

    private var dateFormatter: DateFormatter = .init()

    private var dayLabels: [UILabel] = []

    private let reuseQueue: ReusableObjectQueue = .init()

    private var eventRows: OrderedDictionary<Date, EventsRowView> = .init(
        minimumCapacity: rowCacheSize
    )

    private var interactiveCell: EventView?

    private var isInteractiveCellForNewEvent: Bool = false

    private var interactiveCellTouchPoint: CGPoint?

    private var dragEventIndex: Int? = -1

    private var dragEventDate: Date?

    private var dragEventDateRange: DateRange?

    private var dragEventTouchDayOffset: Int?

    private weak var dragTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    private func setup() {
        dateFormatter.calendar = calendar
        dateFormatter.locale = .current
        dateFormatter.dateFormat = DateFormatter.dateFormat(
            fromTemplate: defaultDateFormat,
            options: 0,
            locale: .current
        )

        dayLabels = Array(repeating: UILabel(), count: 7)

        reuseQueue.register(
            EventsRowView.self,
            forObjectWithReuseIdentifier: ReusableConstants.Identifier.eventsRowView
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        // the order in which subviews are added is important here -
        // see UIViewController automaticallyAdjustsScrollViewInsets property:
        // if the first subview of the controller's view is a scrollview,
        // its insets may be adjusted to account for screen areas consumed by navigation bar...

        let insets: UIEdgeInsets =
            traitCollection.isPortrait
            ? .zero
            : .init(top: 0, left: safeAreaInsets.left, bottom: 0, right: safeAreaInsets.right)

        eventsView.frame = bounds.inset(by: insets)

        if eventsView.superview == nil {
            addSubview(eventsView)
        }

        // we have to reload everything at this point - layout invalidation is not enough -
        // because date formats for headers might change depending on available size
        eventsView.reloadData()
    }

    private func maxSize(for font: UIFont, toFitStrings strings: [String], inSize size: CGSize)
        -> CGFloat
    {
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 0.1

        var fontSize = font.pointSize

        for str in strings {
            let attrStr = NSAttributedString(
                string: str,
                attributes: [NSAttributedString.Key.font: font]
            )
            attrStr.boundingRect(with: size, options: .usesLineFragmentOrigin, context: context)
            fontSize = min(fontSize, font.pointSize * context.actualScaleFactor)
        }

        return floor(fontSize)
    }

    @objc private func applicationDidReceiveMemoryWarning(_ notification: Notification) {
        guard let visibleDays = visibleDays() else { return }

        var delete: [Date] = []

        for date in eventRows.keys {
            if !visibleDays.contains(date) {
                delete.append(date)
            }
        }
        eventRows.removeAll { item in
            delete.contains(item.key)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func dateForDay(at indexPath: IndexPath) -> Date {
        let components = DateComponents(month: indexPath.section)
        
        let date = calendar.date(byAdding: components, to: startDate)!
        print("section: \(indexPath.section), item: \(indexPath.item), start: \(startDate), date: \(date)")
        
        let newStart = date.firstDayOfFirstWeek
        let newDate = calendar.date(byAdding: .init(day: indexPath.item), to: newStart)!
        print("newStart: \(newStart), newDate: \(newDate)")
        
        return newDate
    }

    private func indexPath(for date: Date) -> IndexPath? {
        guard loadedDateRange.contains(date) else { return nil }
        let components = calendar.dateComponents([.month, .day], from: startDate, to: date)
        return IndexPath(item: components.day!, section: components.month!)
    }

    private func indexPathsForDays(in dateRange: DateRange) -> [IndexPath] {
        var indexPaths: [IndexPath] = []
        var components = DateComponents()
        components.day = 0

        var date = calendar.startOfDay(for: dateRange.start)

        while dateRange.contains(date) {
            if let index = indexPath(for: date) {
                indexPaths.append(index)
            }

            components.day! += 1
            date = calendar.date(byAdding: components, to: dateRange.start)!
        }

        return indexPaths
    }

    /// first day of month at index
    private func dateStartingMonth(at month: Int) -> Date {
        dateForDay(at: .init(item: 0, section: month))
    }

    private func numberOfDaysForMonth(at month: Int) -> Int {
//        let date = dateStartingMonth(at: month)
        let components = DateComponents(month: month, day: 0)
        let date = calendar.date(byAdding: components, to: startDate)!
        
        let start = calendar.firstDayOfFirstWeekInMonth(for: date)
        let end = calendar.lastDayOfLastWeekOfMonth(for: date)
        let days = calendar.dateComponents([.day], from: start, to: end).day
        print("numberOfDays date: \(date), start: \(start), end: \(end), days: \(days!)")

        return  days! + 1
        
//        let range = calendar.range(of: .day, in: .month, for: date)!
//        return range.count
    }

    private func columnForDay(at indexPath: IndexPath) -> Int {
        let date = dateForDay(at: indexPath)
        let weekday = calendar.dateComponents([.weekday], from: date).weekday!
        return (weekday + 7 - calendar.firstWeekday) % 7
    }

    private func dateRange(for eventsRowView: EventsRowView) -> DateRange? {
        let start = calendar.date(
            byAdding: .day,
            value: eventsRowView.daysRange.location,
            to: eventsRowView.referenceDate!
        )
        let end = calendar.date(
            byAdding: .day,
            value: NSMaxRange(eventsRowView.daysRange),
            to: eventsRowView.referenceDate!
        )
        return .init(start: start!, end: end!)
    }

    private func yOffsetForMonth(_ date: Date) -> CGFloat {
        let startOfMonth = calendar.startOfMonth(for: date)
        let comps = calendar.dateComponents([.month], from: startDate, to: startOfMonth)
        let monthsDiff = labs(comps.month!)

        var month = min(startOfMonth, startDate)

        var offset: CGFloat = 0

        for _ in 0..<monthsDiff {
            offset += heightForMonth(at: month)
            month = calendar.date(byAdding: .month, value: 1, to: month)!
        }

        if startOfMonth < startDate {
            offset = -offset
        }

        return offset
    }

    private func xOffsetForMonth(_ date: Date) -> CGFloat {
        let startOfMonth = calendar.startOfMonth(for: date)
        let comps = calendar.dateComponents([.month], from: startDate, to: startOfMonth)
        let monthsDiff = labs(comps.month!)

        var month = min(startOfMonth, startDate)

        var offset: CGFloat = 0

        for _ in 0..<monthsDiff {
            offset += widthForMonth(at: date)
            month = calendar.date(byAdding: .month, value: 1, to: month)!
        }

        if startOfMonth < startDate {
            offset = -offset
        }

        return offset
    }

    private func monthFromOffset(_ yOffset: CGFloat) -> Date {
        var month = startDate
        var y = yOffset > 0 ? heightForMonth(at: month) : 0
        while y < abs(yOffset) {
            month = calendar.date(byAdding: .month, value: yOffset > 0 ? 1 : -1, to: month)!
            y += heightForMonth(at: month)
        }
        return month
    }

    private func monthFromXOffset(_ xOffset: CGFloat) -> Date {
        var month = startDate
        var x = xOffset > 0 ? widthForMonth(at: month) : 0
        while x < abs(xOffset) {
            month = calendar.date(byAdding: .month, value: xOffset > 0 ? 1 : -1, to: month)!
            x += widthForMonth(at: month)
        }
        return month
    }

    private func reload() {
        deselectEvent(tellDelegate: true)
        clearRowsCache(in: nil)

        eventsView.reloadData()
    }

    func maxSize(for font: UIFont, toFit strings: [String], in size: CGSize) -> CGFloat {
        let context = NSStringDrawingContext()
        context.minimumScaleFactor = 0.1

        var fontSize = font.pointSize

        for str in strings {
            let attrStr = NSAttributedString(
                string: str,
                attributes: [NSAttributedString.Key.font: font]
            )
            attrStr.boundingRect(with: size, options: .usesLineFragmentOrigin, context: context)
            fontSize = min(fontSize, font.pointSize * context.actualScaleFactor)
        }

        return floor(fontSize)
    }

    func deselectEvent(tellDelegate: Bool) {
        guard
            let selectedEventDate,
            let selectedEventIndex,
            let cell = cellForEvent(at: selectedEventIndex, date: selectedEventDate)
        else { return }

        cell.selected = false

        if tellDelegate {
            delegate?
                .monthPlanView(
                    self,
                    didDeselectEventAt: selectedEventIndex,
                    date: selectedEventDate
                )
        }

        self.selectedEventDate = nil
    }

    /// if range is nil, remove all entries
    func clearRowsCache(in dateRange: DateRange?) {
        for date in eventRows.keys {
            if dateRange?.contains(date) == true || dateRange == nil {
                removeRow(at: date)
            }
        }
    }

    func removeRow(at date: Date) {
        guard let remove = eventRows[date] else { return }
        reuseQueue.enqueue(remove)
        eventRows.removeValue(forKey: date)
    }

    private func eventsRowView(at rowStart: Date) -> EventsRowView? {
        if let eventsView = eventRows[rowStart] {
            return eventsView
        }

        guard
            let eventsRowView = reuseQueue.dequeue(
                by: ReusableConstants.Identifier.eventsRowView
            ) as? EventsRowView
        else { return nil }

        let referenceDate = calendar.startOfMonth(for: rowStart)

        guard
            let first = calendar.dateComponents([.day], from: referenceDate, to: rowStart).day,
            let numDays = calendar.range(of: .day, in: .weekOfMonth, for: rowStart)?.count
        else { return nil }

        eventsRowView.referenceDate = referenceDate
        eventsRowView.isScrollEnabled = false
        eventsRowView.itemHeight = itemHeight
        eventsRowView.eventsRowDelegate = self
        eventsRowView.daysRange = NSMakeRange(first, numDays)

        eventsRowView.reload()
        cacheRow(eventsRowView, for: rowStart)

        return eventsRowView
    }

    private func cacheRow(_ eventsView: EventsRowView, for date: Date) {
        if let _ = eventRows[date] {
            // if already in the cache, we remove it first
            // because we want to keep the list in strict MRU order
            eventRows.removeValue(forKey: date)
        }

        eventRows[date] = eventsView

        if eventRows.count >= rowCacheSize {
            removeRow(at: eventRows.keys[0])
        }
    }

    private func monthRowView(at indexPath: IndexPath) -> MonthPlanWeekView? {
        guard
            let rowView = eventsView.dequeueReusableSupplementaryView(
                ofKind: ReusableConstants.Kind.monthRow,
                withReuseIdentifier: ReusableConstants.Identifier.monthRowView,
                for: indexPath
            ) as? MonthPlanWeekView
        else { return nil }

        let rowStart = dateForDay(at: indexPath)
        let eventsView = eventsRowView(at: rowStart)
        rowView.eventsView = eventsView

        return rowView
    }

    private func bounceAnimateCell(_ cell: EventView) {
        let frame = cell.frame
        UIView.animate(withDuration: 0.2, delay: 0, options: .repeat) {
            UIView.modifyAnimations(withRepeatCount: 2, autoreverses: true) {
                cell.frame = cell.frame.insetBy(dx: -4, dy: -2)
            }
        } completion: { _ in
            cell.frame = frame
        }
    }

    private func daysRange(from dateRange: DateRange) -> DateRange {
        let start = calendar.startOfDay(for: dateRange.start)
        var end = calendar.startOfDay(for: dateRange.end)

        if end.compare(dateRange.end) != .orderedSame {
            var comps = DateComponents()
            comps.day = 1
            end = calendar.date(byAdding: comps, to: end)!
        }
        return DateRange(start: start, end: end)
    }

    private func highlightDays(in range: DateRange?) {
        if let range = range {
            let paths = indexPathsForDays(in: daysRange(from: range))
            for path in paths {
                if let dayCell = eventsView.cellForItem(at: path) as? MonthPlanViewDayCell {
                    dayCell.isHighlighted = true
                }
            }
        } else {
            let visible = eventsView.visibleCells
            for cell in visible {
                if let dayCell = cell as? MonthPlanViewDayCell {
                    dayCell.isHighlighted = false
                }
            }
        }
    }

    private func didStartLongPress(at point: CGPoint) -> Bool {
        // just in case previous operation did not end properly...
        endInteraction()

        var date: Date?
        var index: Int = 0
        guard let eventCell = eventCell(at: point, date: &date, index: &index) else {
            if !canCreateEvents { return false }

            isInteractiveCellForNewEvent = true
            // create a new cell
            if let dataSource = dataSource {
                interactiveCell = dataSource.monthPlanView(self, cellForNewEventAt: date!)
            } else {
                let cell = StandardEventView(frame: .zero)
                cell.title = NSLocalizedString("New Event", comment: "")
                interactiveCell = cell
            }
            interactiveCell!.frame = CGRect(
                x: 0,
                y: 0,
                width: layout.columnWidth(0),
                height: itemHeight
            )
            interactiveCellTouchPoint = CGPoint(x: layout.columnWidth(0) / 2, y: itemHeight / 2)
            interactiveCell!.center = convert(point, to: eventsView)
            return true
        }

        // a cell was touched
        if !canMoveEvents { return false }

        if let dataSource = dataSource {
            if !dataSource.monthPlanView(self, canMoveCellForEventAt: index, date: date!) {
                bounceAnimateCell(eventCell)
                return false  // cancel gesture
            }
        }

        if let delegate = delegate {
            delegate.monthPlanView(self, willStartMovingEventAt: index, date: date!)
        }

        dragEventDate = date
        dragEventIndex = index
        dragEventDateRange = dataSource?
            .monthPlanView(self, dateRangeForEventAt: index, date: date!)

        let touchDate = day(at: point)!
        let eventDayStart = calendar.startOfDay(for: dragEventDateRange!.start)
        dragEventTouchDayOffset =
            calendar.dateComponents([.day], from: touchDate, to: eventDayStart).day!

        highlightDays(in: dragEventDateRange)

        isInteractiveCellForNewEvent = false
        interactiveCellTouchPoint = convert(point, to: eventCell)

        interactiveCell = dataSource?.monthPlanView(self, cellForEventAt: index, date: date!)

        // adjust the frame
        let frame = eventsView.convert(eventCell.bounds, from: eventCell)
        interactiveCell!.frame = frame

        // show the interactive cell
        interactiveCell!.selected = true
        eventsView.addSubview(interactiveCell!)
        interactiveCell!.isHidden = false
        return true
    }

    private func didEndLongPress(atPoint pt: CGPoint) {
        dragTimer?.invalidate()
        dragTimer = nil

        if let day = day(at: pt) {
            if !isInteractiveCellForNewEvent {
                var comps = calendar.dateComponents(
                    [.hour, .minute],
                    from: dragEventDateRange!.start
                )
                comps.day = dragEventTouchDayOffset
                let startDate = calendar.date(byAdding: comps, to: day)!

                // move only if new start is different from old start
                if startDate.compare(dragEventDateRange!.start) != .orderedSame {
                    delegate?
                        .monthPlanView(
                            self,
                            didMoveEventAt: dragEventIndex!,
                            fromDate: dragEventDate!,
                            toDate: startDate
                        )
                    return
                }
            } else {
                delegate?.monthPlanView(self, didShow: interactiveCell!, forNewEventAt: day)
                return
            }
        }

        endInteraction()
    }

    private func moveInteractiveCell(at point: CGPoint) {
        highlightDays(in: nil)

        if let hoveredDate = day(at: point) {
            var highlightStart = hoveredDate
            if let dragEventDate {
                var comps = DateComponents()
                comps.day = dragEventTouchDayOffset
                highlightStart = calendar.date(byAdding: comps, to: hoveredDate)!
            }

            var comps = DateComponents()
            if isInteractiveCellForNewEvent {
                comps.day = 1
            } else {
                comps.day =
                    daysRange(from: dragEventDateRange!)
                    .components(unitFlags: [.day], for: calendar).day
            }
            let highlightEnd = calendar.date(byAdding: comps, to: highlightStart)!
            let highlight = DateRange(start: highlightStart, end: highlightEnd)

            highlightDays(in: highlight)
        } else {
            highlightDays(in: dragEventDateRange)
        }

        if point.x > eventsView.frame.maxX - dragScrollZoneSize {
            dragTimer?.invalidate()
            dragTimer = Timer.scheduledTimer(
                timeInterval: 0.05,
                target: self,
                selector: #selector(dragTimer(_:)),
                userInfo: ["direction": CalendarViewScrollingDirection.down],
                repeats: true
            )
        } else if point.x < self.headerHeight + dragScrollZoneSize {
            dragTimer?.invalidate()
            dragTimer = Timer.scheduledTimer(
                timeInterval: 0.05,
                target: self,
                selector: #selector(dragTimer(_:)),
                userInfo: ["direction": CalendarViewScrollingDirection.up],
                repeats: true
            )
        } else if dragTimer != nil {
            dragTimer?.invalidate()
            dragTimer = nil
        }

        var frame = interactiveCell!.frame
        frame.origin = convert(point, to: eventsView)
        frame = frame.offsetBy(dx: -interactiveCellTouchPoint!.x, dy: -interactiveCellTouchPoint!.y)
        interactiveCell?.frame = frame
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {

        let pt = gesture.location(in: self)

        // long press on a cell or an empty space
        if gesture.state == .began {
            isUserInteractionEnabled = false

            if !didStartLongPress(at: pt) {
                // cancel gesture
                gesture.isEnabled = false
                gesture.isEnabled = true
            }
        }
        // interactive cell was moved
        else if gesture.state == .changed {
            moveInteractiveCell(at: pt)
        }
        // finger was lifted
        else if gesture.state == .ended {
            didEndLongPress(atPoint: pt)
            isUserInteractionEnabled = true
        }
        // gesture was canceled
        else {
            endInteraction()
            isUserInteractionEnabled = true
        }
    }

    @objc private func dragTimer(_ timer: Timer) {
        guard
            let info = timer.userInfo as? [String: Any],
            let value = info["direction"] as? Int,
            let scrollDirection = CalendarViewScrollingDirection(rawValue: value),
            let interactiveCell
        else { return }

        var newOffset = eventsView.contentOffset
        var frame = interactiveCell.frame

        switch scrollDirection {
        case .up:
            newOffset.y = max(newOffset.y - dragScrollOffset, 0)
            frame.origin.y -= dragScrollOffset
        case .down:
            newOffset.y = min(
                newOffset.y + dragScrollOffset,
                eventsView.contentSize.height - eventsView.bounds.size.height
            )
            frame.origin.y += dragScrollOffset
        }

        interactiveCell.frame = frame
        eventsView.setContentOffset(newOffset, animated: false)
    }

    private var monthMinimumHeight: CGFloat {
        let numWeeks = calendar.minimumRange(of: .weekOfMonth)?.count ?? 0
        return CGFloat(numWeeks) * layout.rowHeight + monthInsets.top + monthInsets.bottom
    }

    private var monthMaximumHeight: CGFloat {
        let numWeeks = calendar.maximumRange(of: .weekOfMonth)?.count ?? 0
        return CGFloat(numWeeks) * layout.rowHeight + monthInsets.top + monthInsets.bottom
    }

    private var monthMinimumWidth: CGFloat {
        eventsView.bounds.width - monthInsets.left - monthInsets.right
    }

    private var monthMaximumWidth: CGFloat {
        return eventsView.bounds.width - monthInsets.left - monthInsets.right
        //        let numWeeks = calendar.maximumRange(of: .weekOfMonth)?.count ?? 0
        //        return CGFloat(numWeeks) * rowHeight + monthInsets.top + monthInsets.bottom
    }

    private func heightForMonth(at date: Date) -> CGFloat {
        let monthStart = calendar.startOfMonth(for: date)
        let numWeeks = calendar.range(of: .weekOfMonth, in: .month, for: monthStart)?.count ?? 0
        return CGFloat(numWeeks) * layout.rowHeight + monthInsets.top + monthInsets.bottom
    }

    private func widthForMonth(at date: Date) -> CGFloat {
        eventsView.bounds.width
        //        let monthStart = calendar.startOfMonth(for: date)
        //        let numWeeks = calendar.range(of: .weekOfMonth, in: .month, for: monthStart)?.count ?? 0
        //        return CGFloat(numWeeks) * rowHeight + monthInsets.top + monthInsets.bottom
    }

    private func visibleEventRows() -> [EventsRowView] {
        guard let visibleDays = visibleDays() else { return [] }

        var rows = [EventsRowView]()

        for (date, rowView) in eventRows {
            if visibleDays.contains(date) {
                rows.append(rowView)
            }
        }

        return rows
    }

    private lazy var headerDateFormatter: DateFormatter = {
        let format = DateFormatter()
        format.locale = .current
        format.calendar = calendar
        return format
    }()
}

// MARK: - UICollectionViewDataSource
extension MonthPlanView: UICollectionViewDataSource {
    public func numberOfSections(
        in collectionView: UICollectionView
    ) -> Int {
        numberOfLoadedMonths
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        numberOfDaysForMonth(at: section)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        let cell = eventsView.dequeueReusableCell(
            for: indexPath,
            cellType: MonthPlanViewDayCell.self
        )

        cell.headerHeight = dayCellHeaderHeight

        let date = dateForDay(at: indexPath)
//        print("cellForItemSection: \(indexPath.section), item: \(indexPath.item), date: \(date)")

        var attrStr = delegate?.monthPlanView(self, attributedStringForDayHeaderAt: date)

        if attrStr == nil {
            dateFormatter.dateFormat = "d"
            let str = dateFormatter.string(from: date)

            let para = NSMutableParagraphStyle()
            para.alignment = .center

            let textColor: UIColor =
                calendar.isDate(date, inSameDayAs: .init()) ? .tintColor : .label

            attrStr = NSAttributedString(
                string: str,
                attributes: [
                    .paragraphStyle: para,
                    .foregroundColor: textColor,
                ]
            )
        }

        cell.dayLabel.attributedText = attrStr
        cell.backgroundColor =
            calendar.isDateInWeekend(date)
            ? weekendDayBackgroundColor
            : weekDayBackgroundColor

        return cell
    }

    func headerViewForMonth(at indexPath: IndexPath) -> MonthPlanMonthHeaderView {
        guard
            let view = eventsView.dequeueReusableSupplementaryView(
                ofKind: ReusableConstants.Kind.monthHeader,
                withReuseIdentifier: ReusableConstants.Identifier.monthHeaderView,
                for: indexPath
            ) as? MonthPlanMonthHeaderView
        else { return .init(frame: .zero) }

        let dateFormatter = DateFormatter()  // TODO: DateFormatter
        dateFormatter.calendar = calendar
        view.weekStrings = dateFormatter.shortStandaloneWeekdaySymbols

        scrollViewDidEndDecelerating(eventsView)

        return view
    }

    func backgroundViewForMonth(at indexPath: IndexPath) -> MonthPlanBackgroundView {
        guard
            let view = eventsView.dequeueReusableSupplementaryView(
                ofKind: ReusableConstants.Kind.monthBackground,
                withReuseIdentifier: ReusableConstants.Identifier.monthBackgroundView,
                for: indexPath
            ) as? MonthPlanBackgroundView
        else { return .init(frame: .zero) }

        let date = dateStartingMonth(at: indexPath.section)

        let firstColumn = columnForDay(at: IndexPath(item: 0, section: indexPath.section))
        let lastColumn = columnForDay(at: IndexPath(item: 0, section: indexPath.section + 1))
        let numRows = calendar.range(of: .weekOfMonth, in: .month, for: date)?.count

        view.numberOfColumns = 7
        view.numberOfRows = numRows!
        view.firstColumn = gridStyle.contains(.fill) ? 0 : firstColumn
        view.lastColumn = gridStyle.contains(.fill) ? 7 : lastColumn
        view.drawVerticalLines = gridStyle.contains(.verticalLines)
        view.drawHorizontalLines = gridStyle.contains(.horizontalLines)
        view.drawBottomDayLabelLines = gridStyle.contains(.bottomDayLabel)
        view.dayCellHeaderHeight = dayCellHeaderHeight

        view.setNeedsDisplay()

        return view
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {

        switch kind {
        case ReusableConstants.Kind.monthBackground:
            return backgroundViewForMonth(at: indexPath)
        case ReusableConstants.Kind.monthHeader:
            return headerViewForMonth(at: indexPath)
        case ReusableConstants.Kind.monthRow:
            return monthRowView(at: indexPath)!
        default:
            return UICollectionReusableView()
        }
    }
}

// MARK: - EventsRowViewDelegate
extension MonthPlanView: EventsRowViewDelegate {

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        numberOfEventsForDayAtIndex day: Int
    ) -> Int {
        let comps = DateComponents(day: day)
        let date = calendar.date(byAdding: comps, to: eventsRowView.referenceDate!)
        let count = dataSource?.monthPlanView(self, numberOfEventsAt: date!)
        return count ?? 0
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        rangeForEventAt indexPath: IndexPath
    ) -> NSRange {
        let comps = DateComponents(day: indexPath.section)
        let date = calendar.date(byAdding: comps, to: eventsRowView.referenceDate!)!

        let dateRange = dataSource!
            .monthPlanView(self, dateRangeForEventAt: indexPath.item, date: date)

        var start = max(
            0,
            calendar.dateComponents(
                [.day],
                from: eventsRowView.referenceDate!,
                to: dateRange.start
            )
            .day!
        )
        var end =
            calendar.dateComponents(
                [.day],
                from: eventsRowView.referenceDate!,
                to: dateRange.end
            )
            .day!
        if dateRange.end.timeIntervalSince(calendar.startOfDay(for: dateRange.end)) >= 0 {
            end += 1
        }
        end = min(end, NSMaxRange(eventsRowView.daysRange))

        return NSMakeRange(start, end - start)
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        cellForEventAt indexPath: IndexPath
    ) -> EventView {
        let comps = DateComponents(day: indexPath.section)
        let date = calendar.date(byAdding: comps, to: eventsRowView.referenceDate!)!
        return dataSource!.monthPlanView(self, cellForEventAt: indexPath.item, date: date)
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        widthForDayRange range: NSRange
    ) -> CGFloat {
        layout.widthForColumnRange(range)
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        shouldSelectCellAt indexPath: IndexPath
    ) -> Bool {
        guard allowSelection else { return false }

        let comps = DateComponents(day: indexPath.section)
        let date = calendar.date(byAdding: comps, to: eventsRowView.referenceDate!)!

        return delegate?
            .monthPlanView(
                self,
                shouldSelectEventAt: indexPath.item,
                date: date
            )
            ?? false
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        didSelectCellAt indexPath: IndexPath
    ) {
        deselectEvent(tellDelegate: true)

        let comps = DateComponents(day: indexPath.section)
        let date = calendar.date(byAdding: comps, to: eventsRowView.referenceDate!)!

        selectedEventDate = date
        selectedEventIndex = indexPath.item

        delegate?.monthPlanView(self, didSelectEventAt: indexPath.item, date: date)
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        shouldDeselectCellAt indexPath: IndexPath
    ) -> Bool {
        let comps = DateComponents(day: indexPath.section)
        let date = calendar.date(byAdding: comps, to: eventsRowView.referenceDate!)!

        return delegate?
            .monthPlanView(
                self,
                shouldDeselectEventAt: indexPath.item,
                date: date
            ) ?? false
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        didDeselectCellAt indexPath: IndexPath
    ) {
        let comps = DateComponents(day: indexPath.section)
        let date = calendar.date(byAdding: comps, to: eventsRowView.referenceDate!)!

        if selectedEventDate == date && indexPath.item == selectedEventIndex {
            selectedEventDate = nil
            selectedEventIndex = 0
        }

        delegate?
            .monthPlanView(
                self,
                didSelectEventAt: indexPath.item,
                date: date
            )
    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        willDisplay cell: EventView,
        forEventAt indexPath: IndexPath
    ) {

    }

    public func eventsRowView(
        _ eventsRowView: EventsRowView,
        didEndDisplaying cell: EventView,
        forEventAt indexPath: IndexPath
    ) {
        reuseQueue.enqueue(cell)
    }
}

// MARK: - MonthPlannerViewLayoutDelegate
extension MonthPlanView: MonthPlannerViewLayoutDelegate {

    public func collectionView(
        _ collectionView: UICollectionView,
        layout: MonthPlanViewLayout,
        columnForDayAt indexPath: IndexPath
    ) -> Int {
        columnForDay(at: indexPath)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let date = dateForDay(at: indexPath)
        delegate?.monthPlanView(self, didSelectDayCellAt: date)

        if let index = eventsView.indexPathsForSelectedItems?.first {
            eventsView.deselectItem(at: index, animated: true)
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        recenterIfNeeded()
        delegate?.monthPlanViewDidScroll(self)
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard let idx = eventsView.indexPathsForVisibleItems.first else { return }
        currentDisplayingMonthDate = dateStartingMonth(at: idx.section)
    }

    //    func scrollViewWillEndDragging(
    //        _ scrollView: UIScrollView,
    //        withVelocity velocity: CGPoint,
    //        targetContentOffset: UnsafeMutablePointer<CGPoint>
    //    ) {
    //        let kFlickVelocity: CGFloat = 0.2
    //
    //        var xOffsetMin: CGFloat = 0  //pagingMode == .headerTop ? 0 : monthInsets.top
    //        var xOffsetMax: CGFloat = monthMaximumWidth
    //
    //        var monthStart = startDate
    //        for _ in 0..<numberOfLoadedMonths {
    //            let offset = xOffsetMin + widthForMonth(at: monthStart)
    //            if offset > scrollView.contentOffset.x {
    //                xOffsetMax = offset
    //                break
    //            }
    //            xOffsetMin = offset
    //
    //            monthStart = Calendar.current.date(byAdding: .month, value: 1, to: monthStart)!
    //        }
    //
    //        // we need to had a few checks to avoid flickering when swiping fast on a small distance
    //        // see http://stackoverflow.com/a/14291208/740949
    //        let deltaX = targetContentOffset.pointee.x - scrollView.contentOffset.x
    //        let mightFlicker = (velocity.x > 0.0 && deltaX > 0.0) || (velocity.x < 0.0 && deltaX < 0.0)
    //
    //        if abs(velocity.x) < kFlickVelocity && !mightFlicker {
    //            // stick to nearest section
    //            if scrollView.contentOffset.x - xOffsetMin < xOffsetMax - scrollView.contentOffset.x {
    //                targetContentOffset.pointee.x = xOffsetMin
    //            } else {
    //                targetContentOffset.pointee.x = xOffsetMax
    //            }
    //        } else {
    //            // scroll to next page
    //            if velocity.x > 0 {
    //                targetContentOffset.pointee.x = xOffsetMax
    //            } else {
    //                targetContentOffset.pointee.x = xOffsetMin
    //            }
    //        }
    //    }
}
