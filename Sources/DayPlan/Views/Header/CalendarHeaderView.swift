//
//  CalendarHeaderView.swift
//  CalLib
//
//  Created by mwf on 2023/8/23.
//

import Reusable
import UIKit

enum HeaderSection: Int {
    case previous = 0
    case current, next
}

class CalendarHeaderView: UICollectionView {
    
    private let numberOfDaysToDisplay = 7
    private let detailsLabelHeight: CGFloat = 20
    private let itemHeight: CGFloat = 60

    private(set) var selectedDate: Date

    var headerBackgroundColor: UIColor = .lightGray

    let dayPlannerView: DayPlanView
    private let flowLayout: UICollectionViewFlowLayout
    private var calendar: Calendar
    /// keeps the count of scrolls left or right, where 0 is no scrolls -1 is one scroll left +1 is one scroll right
    private var weekIndex: Int
    private var selectedDateIndex: Int

    private var previousWeekDates: [Date] = []
    private var currentWeekDates: [Date] = []
    private var nextWeekDates: [Date] = []
    private var previousContentOffset: CGPoint = .zero

    init(
        frame: CGRect,
        collectionViewLayout layout: UICollectionViewLayout,
        dayPlannerView: DayPlanView
    ) {
        self.dayPlannerView = dayPlannerView

        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.sectionInset = .zero
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        self.flowLayout = flowLayout

        calendar = .current
        calendar.locale = .current
        weekIndex = 0

        selectedDate = calendar.startOfDay(for: Date())
        selectedDateIndex = calendar.component(.weekday, from: selectedDate) - 1  // -1 as 1 is the first day of the week, but we are dealing with arrays starting on 0

        super.init(frame: frame, collectionViewLayout: layout)

        isPagingEnabled = true
        delegate = self
        dataSource = self
        allowsMultipleSelection = false
        bounces = false
        remembersLastFocusedIndexPath = true
        showsHorizontalScrollIndicator = false
        backgroundColor = headerBackgroundColor

        detailsLabel.text = detailsDateFormatter.string(from: selectedDate)
        addSubview(detailsLabel)

        setupWeekDates()

        register(cellType: CalendarHeaderCell.self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let maxItemWidth = frame.width / CGFloat(numberOfDaysToDisplay)
        flowLayout.itemSize = CGSize(width: maxItemWidth, height: itemHeight)

        // Always select the same day of the week when switching weeks
        // (as the native Apple calendar does)

        selectItem(
            at: .init(item: selectedDateIndex, section: HeaderSection.current.rawValue),
            animated: true,
            scrollPosition: []
        )

        // Recalculate the label size to adapt to rotations
        detailsLabel.frame = CGRect(
            x: previousContentOffset.x,
            y: frame.height - detailsLabelHeight,
            width: frame.width,
            height: detailsLabelHeight
        )
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        layoutIfNeeded()
        scrollToItem(
            at: .init(item: 0, section: HeaderSection.current.rawValue),
            at: .left,
            animated: false
        )
        previousContentOffset = contentOffset
    }

    func select(date: Date) {
        guard !calendar.isDate(date, sameDayAs: selectedDate) else { return }

        selectedDate = calendar.startOfDay(for: date)
        selectedDateIndex = calendar.component(.weekday, from: selectedDate) - 1

        setupWeekDates()

        reloadData()

        // Keep the day view synchronized
        dayPlannerView.scroll(to: date, options: .date, animated: true)

        detailsLabel.text = detailsDateFormatter.string(from: date)
    }

    private func setupWeekDates() {
        var components = DateComponents()

        components.weekOfYear = weekIndex
        let currentWeekDate = calendar.date(byAdding: components, to: selectedDate)
        currentWeekDates = weekDays(from: currentWeekDate!)

        components.weekOfYear = weekIndex + 1
        let nextWeekDate = calendar.date(byAdding: components, to: selectedDate)
        nextWeekDates = weekDays(from: nextWeekDate!)

        components.weekOfYear = weekIndex - 1
        let previousWeekDate = calendar.date(byAdding: components, to: selectedDate)
        previousWeekDates = weekDays(from: previousWeekDate!)
    }

    private func weekDays(from date: Date) -> [Date] {
        var components = calendar.dateComponents(
            [.year, .month, .weekOfYear, .weekday, .hour, .minute],
            from: date
        )

        var weekDaysDates: [Date] = []

        // Iterate to fill the dates of the week days
        for i in 1...7 {  // 1 is the component for the first day of the week, 7 is the last
            components.weekday = i
            if let date = calendar.date(from: components) {
                weekDaysDates.append(date)
            }
        }

        return weekDaysDates
    }

    private lazy var detailsLabel: UILabel = {
        let label = UILabel()
        label.backgroundColor = headerBackgroundColor
        label.textColor = .darkGray
        label.textAlignment = .center
        return label
    }()

    private lazy var detailsDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = .current
        return formatter
    }()
}

extension CalendarHeaderView: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        3
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        numberOfDaysToDisplay
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            for: indexPath,
            cellType: CalendarHeaderCell.self
        )

        let section = HeaderSection(rawValue: indexPath.section)
        switch section {
        case .previous:
            cell.date = previousWeekDates[indexPath.item]
        case .current:
            cell.date = currentWeekDates[indexPath.item]
        case .next:
            cell.date = nextWeekDates[indexPath.item]
        case .none:
            break
        }

        return cell
    }
}

extension CalendarHeaderView: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        guard
            let cell = collectionView.cellForItem(at: indexPath) as? CalendarHeaderCell,
            let date = cell.date
        else { return }

        select(date: date)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        var newDate = currentWeekDates[selectedDateIndex]

        if contentOffset.x > previousContentOffset.x {
            // The user scrolled to the left, moving to the next week
            newDate = nextWeekDates[selectedDateIndex]
        } else if contentOffset.x < previousContentOffset.x {
            // The user scrolled to the right, moving to the previous week
            newDate = previousWeekDates[selectedDateIndex]
        }

        // Small visual trick to provide the feeling of infinite scrolling,
        // actually resetting the position without animation
        scrollToItem(
            at: .init(item: 0, section: HeaderSection.current.rawValue),
            at: .left,
            animated: false
        )

        select(date: newDate)
    }
}
