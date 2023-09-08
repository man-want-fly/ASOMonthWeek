//
//  AllDayEventViewLayout.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import UIKit

struct AllDayEventInset: OptionSet {

    let rawValue: Int

    static let none: AllDayEventInset = []
    static let left = AllDayEventInset(rawValue: 1 << 0)
    static let right = AllDayEventInset(rawValue: 1 << 1)
}

protocol AllDayEventViewLayoutDelegate: AnyObject {

    func collectionView(
        _ collectionView: UICollectionView,
        layout: AllDayEventsViewLayout,
        dayRangeForEventAt indexPath: IndexPath
    ) -> NSRange?

    func collectionView(
        _ collectionView: UICollectionView,
        layout: AllDayEventsViewLayout,
        insetsForEventAt indexPath: IndexPath
    ) -> AllDayEventInset
}

private let cellSpacing: CGFloat = 2  // space around cells
private let cellInset: CGFloat = 4

class AllDayEventsViewLayout: UICollectionViewLayout {

    weak var delegate: AllDayEventViewLayoutDelegate?

    var dayColumnWidth: CGFloat = 60
    var eventCellHeight: CGFloat = 20
    var maxContentHeight: CGFloat = 1000//.greatestFiniteMagnitude
    private var visibleSections: NSRange = .init(location: 0, length: 0)

    private var maxEventsInSections: Int = 0

    /// cache of events count per day [ { day : count }, ... ]
    private var eventsCount: [Int: Int] = [:]
    /// cache of hidden events count per day
    private var hiddenCount: [Int: Int] = [:]

    private var layoutInfos: [String: [IndexPath: UICollectionViewLayoutAttributes]] = [:]

    var maxVisibleLines: Int {
        let lines = (maxContentHeight + cellSpacing + 1) / (eventCellHeight + cellSpacing)
        guard !(lines.isNaN || lines.isInfinite) else { return 0 }
        return Int(exactly: lines.rounded()) ?? 0
    }

    func maxVisibleLinesForDays(in range: NSRange) -> Int {
        var count = 0
        for day in range.lowerBound..<range.upperBound {
            count = max(count, numberOfEventsForDay(at: day))
        }
        return count > maxVisibleLines ? maxVisibleLines - 1 : count
    }

    func numberOfEventsForDay(at index: Int) -> Int {
        guard let collectionView else { return 0 }

        if let count = eventsCount[index] {
            return count
        } else {
            let count = collectionView.numberOfItems(inSection: index)
            eventsCount[index] = count
            return count
        }
    }

    func addHiddenEventForDay(at index: Int) {
        let count = hiddenCount[index] ?? 0
        hiddenCount[index] = count + 1
    }

    func numberOfHiddenEvents(in section: Int) -> Int {
        hiddenCount[section] ?? 0
    }

    func eventRanges() -> [IndexPath: NSRange] {
        guard let collectionView else { return [:] }

        var ranges: [IndexPath: NSRange] = [:]

        let visibleSections = visibleDayRange(for: collectionView.bounds)

        var previousDaysWithEvents = false

        for day in visibleSections.location..<NSMaxRange(visibleSections) {
            let count = numberOfEventsForDay(at: day)

            for item in 0..<count {
                let indexPath = IndexPath(item: item, section: day)
                var range = delegate?
                    .collectionView(collectionView, layout: self, dayRangeForEventAt: indexPath)

                if range?.location == day || day == visibleSections.location
                    || !previousDaysWithEvents
                {
                    range = range?.intersection(visibleSections)

                    ranges[indexPath] = range
                }
            }

            if count > 0 {
                previousDaysWithEvents = true
            }
        }

        return ranges
    }

    func rectForCell(
        _ range: NSRange,
        line: Int,
        insets: AllDayEventInset
    ) -> CGRect {
        var x = dayColumnWidth * CGFloat(range.location)
        let y = CGFloat(line) * (eventCellHeight + cellSpacing)
        var width = dayColumnWidth * CGFloat(range.length)

        if insets.contains(.left) {
            x += cellInset
        }

        if insets.contains(.right) {
            width -= cellInset
        }

        return CGRect(x: x, y: y, width: width, height: eventCellHeight)
            .aligned
            .insetBy(dx: cellSpacing, dy: 0)
    }

    func visibleDayRange(for bounds: CGRect) -> NSRange {
        guard let collectionView else { return NSRange(location: 0, length: 0) }
        let maxSection = collectionView.numberOfSections
        let first = Int(max(0, floor(bounds.origin.x / dayColumnWidth)))
        let last = min(
            max(first, Int(ceil(bounds.maxX / dayColumnWidth))),
            maxSection
        )
        guard last > first else { return NSRange(location: 0, length: 0) }
        return .init(location: first, length: last - first)
    }

    override func prepare() {

        guard let collectionView else { return }

        maxEventsInSections = 0
        eventsCount = [:]
        hiddenCount = [:]
        layoutInfos = [:]

        var cellInfos: [IndexPath: UICollectionViewLayoutAttributes] = [:]
        var moreInfos: [IndexPath: UICollectionViewLayoutAttributes] = [:]

        let eventRanges = eventRanges()
        var lines: [NSMutableIndexSet] = []

        for (indexPath, range) in eventRanges.sorted(using: KeyPathComparator(\.key)) {

            var numLine = 0

            for indexes in lines {
                if !indexes.intersects(in: range) {
                    indexes.add(in: range)
                    break
                }
                numLine += 1
            }

            if numLine == lines.count {
                lines.append(.init(indexesIn: range))
            }

            let maxVisibleEvents = maxVisibleLinesForDays(in: range)

            if numLine < maxVisibleEvents {
                let attr = UICollectionViewLayoutAttributes(forCellWith: indexPath)
                let insets = delegate?
                    .collectionView(collectionView, layout: self, insetsForEventAt: indexPath)

                attr.frame = rectForCell(range, line: numLine, insets: insets ?? .none)

                cellInfos[indexPath] = attr

                maxEventsInSections = max(maxEventsInSections, numLine + 1)
            } else {
                for day in range.location..<NSMaxRange(range) {
                    addHiddenEventForDay(at: day)
                    maxEventsInSections = maxVisibleEvents + 1
                }
            }
        }

        let numSections = collectionView.numberOfSections
        for day in 0..<numSections where numberOfHiddenEvents(in: day) > 0 {
            let indexPath = IndexPath(item: 0, section: day)
            let attr = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: ReusableConstants.Kind.moreEvents,
                with: indexPath
            )
            let frame = rectForCell(NSMakeRange(day, 1), line: maxVisibleLines - 1, insets: .none)
            attr.frame = frame
            moreInfos[indexPath] = attr
        }

        layoutInfos["cellInfos"] = cellInfos
        layoutInfos["moreInfos"] = moreInfos
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        return .init(
            width: CGFloat(collectionView.numberOfSections) * dayColumnWidth,
            height: CGFloat(maxEventsInSections) * (eventCellHeight + cellSpacing)
        )
    }

    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {

        var attrs: [UICollectionViewLayoutAttributes] = []

        for items in layoutInfos.values {
            for (_, attr) in items where rect.intersects(attr.frame) && !attr.isHidden {
                attrs.append(attr)
            }
        }

        return attrs
    }

    override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {

        let cellInfos = layoutInfos["cellInfos"]
        let attr = cellInfos?[indexPath]

        if attr == nil {
            let attr = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attr.isHidden = false
            attr.frame = .zero
        }

        return attr
    }

    override func initialLayoutAttributesForAppearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        super.initialLayoutAttributesForAppearingItem(at: itemIndexPath)
    }

    override func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let moreInfos = layoutInfos["moreInfos"]
        let attr = moreInfos?[indexPath]
        if attr == nil {
            let attr = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attr.isHidden = true
            attr.frame = .zero
        }
        return attr
    }

    override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        let oldBounds = collectionView?.bounds ?? .zero

        var shouldInvalidate = oldBounds.width != newBounds.width

        let visibleDays = visibleDayRange(for: newBounds)

        let offContent = newBounds.origin.x < 0 || newBounds.maxX > collectionViewContentSize.width

        if visibleDays != visibleSections && !offContent {
            visibleSections = visibleDays
            shouldInvalidate = true
        }

        return shouldInvalidate
    }
}
