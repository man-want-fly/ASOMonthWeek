//
//  TimedEventViewLayout.swift
//  CalLib
//
//  Created by mwf on 2023/8/21.
//

import UIKit

enum TimedEventCoveringType: Int {
    case classic = 0
    case complex
}

protocol TimedEventsViewLayoutDelegate: AnyObject {

    func collectionView(
        _ collectionView: UICollectionView,
        layout: TimedEventsViewLayout,
        rectForEventAt indexPath: IndexPath
    ) -> CGRect

    func collectionView(
        _ collectionView: UICollectionView,
        layout: TimedEventsViewLayout,
        dimmingRectsFor section: Int
    ) -> [CGRect]
}

class TimedEventsViewLayoutInvalidationContext: UICollectionViewLayoutInvalidationContext {

    var invalidateDimmingViews: Bool = false
    var invalidateEventCells: Bool = true
    var invalidatedSections: IndexSet?
}

class TimedEventsViewLayout: UICollectionViewLayout {
    
    private let dimmingViewsKey = "DimmingViewsKey"
    private let eventCellsKey = "EventCellsKey"

    weak var delegate: TimedEventsViewLayoutDelegate?

    var dayColumnSize: CGSize = .zero

    var minimumVisibleHeight: CGFloat = 15

    var ignoreNextInvalidation: Bool = false

    var coveringType: TimedEventCoveringType = .classic

    /// [Section: [Key: [Attributes]]]
    private var layoutInfo: [Int: [String: [UICollectionViewLayoutAttributes]]] = [:]

    func layoutAttributesForDimmingViews(
        in section: Int
    ) -> [UICollectionViewLayoutAttributes] {

        guard let delegate, let collectionView else { return [] }

        let dimmingRects = delegate.collectionView(
            collectionView,
            layout: self,
            dimmingRectsFor: section
        )

        var attributes: [UICollectionViewLayoutAttributes] = []

        for (index, var rect) in dimmingRects.enumerated() {
            let indexPath = IndexPath(item: index, section: section)
            if !rect.isNull {
                let attribute = UICollectionViewLayoutAttributes(
                    forSupplementaryViewOfKind: ReusableConstants.Kind.dimmingView,
                    with: indexPath
                )
                rect.origin.x = dayColumnSize.width * CGFloat(indexPath.section)
                rect.size.width = dayColumnSize.width

                attribute.frame = rect.aligned

                attributes.append(attribute)
            }
        }
        
        return attributes
    }

    func layoutAttributesForEventCells(
        in section: Int
    ) -> [UICollectionViewLayoutAttributes] {

        guard let delegate, let collectionView else { return [] }

        let numItems = collectionView.numberOfItems(inSection: section)

        var attributes: [EventCellLayoutAttributes] = []

        for i in 0..<numItems {

            let indexPath = IndexPath(item: i, section: section)

            var rect = delegate.collectionView(
                collectionView,
                layout: self,
                rectForEventAt: indexPath
            )

            if !rect.isNull {
                let attribute = EventCellLayoutAttributes(forCellWith: indexPath)

                rect.origin.x = dayColumnSize.width * CGFloat(indexPath.section)
                rect.size.width = dayColumnSize.width
                rect.size.height = fmax(minimumVisibleHeight, rect.height)

                attribute.frame = rect.insetBy(dx: 0, dy: 1).aligned
                attribute.visibleHeight = attribute.frame.height
                attribute.zIndex = 1

                attributes.append(attribute)
            }
        }

        return adjustLayoutForOverlappingCells(attributes, in: section)
    }

    func layoutAttributesForSection(
        _ section: Int
    ) -> [String: [UICollectionViewLayoutAttributes]] {

        var items = layoutInfo[section] ?? [:]

        if items[dimmingViewsKey] == nil {
            items[dimmingViewsKey] = layoutAttributesForDimmingViews(in: section)
        }

        if items[eventCellsKey] == nil {
            items[eventCellsKey] = layoutAttributesForEventCells(in: section)
        }

        layoutInfo[section] = items

        return items
    }

    func adjustLayoutForOverlappingCells(
        _ attributes: [EventCellLayoutAttributes],
        in section: Int
    ) -> [UICollectionViewLayoutAttributes] {

        let adjustedAttributes = attributes.sorted(
            using: KeyPathComparator(\.frame.origin.y)
        )

        switch coveringType {
        case .classic:
            return classicAdjustedLayoutAttributes(adjustedAttributes, in: section)

        case .complex:
            return complexAdjustedLayoutAttributes(adjustedAttributes)
        }
    }

    private func classicAdjustedLayoutAttributes(
        _ adjustedAttributes: [EventCellLayoutAttributes],
        in section: Int
    ) -> [EventCellLayoutAttributes] {
        let overlapOffset: CGFloat = 4

        for i in 0..<adjustedAttributes.count {
            let attr1 = adjustedAttributes[i]

            var groupAttrs = [attr1]

            var coveredLayoutAttributes: [EventCellLayoutAttributes] = []

            for j in (0..<i).reversed() {
                let attr2 = adjustedAttributes[j]

                if attr1.frame.intersects(attr2.frame) {
                    let visibleHeight = abs(attr1.frame.origin.y - attr2.frame.origin.y)
                    if visibleHeight > minimumVisibleHeight {
                        coveredLayoutAttributes.append(attr2)
                        attr2.visibleHeight = visibleHeight
                        attr1.zIndex = attr2.zIndex + 1
                    } else {
                        groupAttrs.append(attr2)
                    }
                }
            }

            var groupOffset: CGFloat = 0

            if coveredLayoutAttributes.count > 0 {
                var lookForEmptySlot = true
                var slotNumber = 0
                var offset: CGFloat = 0

                while lookForEmptySlot {
                    offset = CGFloat(slotNumber) * overlapOffset
                    lookForEmptySlot = false

                    for attribute in coveredLayoutAttributes {
                        if attribute.frame.origin.x - CGFloat(section) * dayColumnSize.width
                            == offset
                        {
                            lookForEmptySlot = true
                            break
                        }
                    }

                    slotNumber += 1
                }

                groupOffset += offset
            }

            let totalWidth = dayColumnSize.width - 1 - groupOffset
            let colWidth = totalWidth / CGFloat(groupAttrs.count)

            var x = CGFloat(section) * dayColumnSize.width + groupOffset

            for attr in groupAttrs.reversed() {
                attr.frame =
                    CGRect(
                        x: x,
                        y: attr.frame.origin.y,
                        width: colWidth,
                        height: attr.frame.height
                    )
                    .aligned
                x += colWidth
            }
        }

        return adjustedAttributes
    }

    private func complexAdjustedLayoutAttributes(
        _ adjustedAttributes: [EventCellLayoutAttributes]
    ) -> [EventCellLayoutAttributes] {

        var uninspectedAttributes = adjustedAttributes

        var clusters: [[EventCellLayoutAttributes]] = []

        while uninspectedAttributes.count > 0 {
            guard
                let attr = uninspectedAttributes.first,
                let index = uninspectedAttributes.firstIndex(of: attr)
            else { break }

            var destinationCluster: [EventCellLayoutAttributes]?

            for cluster in clusters {
                for clusterAttribute in cluster {
                    if clusterAttribute.frame.intersects(attr.frame) {
                        destinationCluster = cluster
                        break
                    }
                }
            }

            if var destinationCluster {
                destinationCluster.append(attr)
            } else {
                clusters.append([attr])
            }

            uninspectedAttributes.remove(at: index)
        }

        for cluster in clusters {
            expandCellsToMaxWidth(in: cluster)
        }

        return clusters.reduce([], +)
    }

    private func expandCellsToMaxWidth(in cluster: [EventCellLayoutAttributes]) {
        var columns: [[EventCellLayoutAttributes]] = []

        for attribute in cluster {
            var isPlaced = false

            for var column in columns {
                if column.isEmpty {
                    column.append(attribute)
                    isPlaced = true
                } else if let last = column.last, !attribute.frame.intersects(last.frame) {
                    column.append(attribute)
                    isPlaced = true
                    break
                }
            }

            if !isPlaced {
                columns.append([attribute])
            }
        }

        var maxRowCount = 0

        for column in columns {
            maxRowCount = max(maxRowCount, column.count)
        }

        let totalWidth = dayColumnSize.width - 2

        for i in 0..<maxRowCount {
            var j = 0

            for column in columns {
                let colWidth = totalWidth / CGFloat(columns.count)

                if column.count >= i + 1 {
                    var attr = column[i]
                    attr.frame =
                        CGRect(
                            x: attr.frame.origin.x + CGFloat(j) * colWidth,
                            y: attr.frame.origin.y,
                            width: colWidth,
                            height: attr.frame.height
                        )
                        .aligned
                }

                j += 1
            }
        }
    }

    //    class func layoutAttributesClass() -> AnyClass {
    //
    //    }

    override class var layoutAttributesClass: AnyClass {
        EventCellLayoutAttributes.self
    }

    override class var invalidationContextClass: AnyClass {
        TimedEventsViewLayoutInvalidationContext.self
    }

    override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let items = layoutAttributesForSection(indexPath.section)
        return items[eventCellsKey]?[indexPath.item]
    }

    override func layoutAttributesForSupplementaryView(
        ofKind elementKind: String,
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let items = layoutAttributesForSection(indexPath.section)
        return items[dimmingViewsKey]?[indexPath.item]
    }

    override func prepare(
        forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]
    ) {
        super.prepare(forCollectionViewUpdates: updateItems)
    }

    override func invalidateLayout(
        with context: UICollectionViewLayoutInvalidationContext
    ) {
        super.invalidateLayout(with: context)

        if ignoreNextInvalidation {
            ignoreNextInvalidation = false
            return
        }

        guard let context = context as? TimedEventsViewLayoutInvalidationContext else { return }

        if context.invalidateEverything || context.invalidatedSections == nil {
            layoutInfo.removeAll()
        } else {
            context.invalidatedSections?.forEach { index in
                if context.invalidateDimmingViews {
                    layoutInfo[index]?.removeValue(forKey: dimmingViewsKey)
                }
                if context.invalidateEventCells {
                    layoutInfo[index]?.removeValue(forKey: eventCellsKey)
                }
            }
        }
    }

    override func invalidateLayout() {
        super.invalidateLayout()
    }

    override var collectionViewContentSize: CGSize {
        guard let collectionView else { return .zero }
        return .init(
            width: dayColumnSize.width * CGFloat(collectionView.numberOfSections),
            height: dayColumnSize.height
        )
    }

    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {

        guard let collectionView else {
            return super.layoutAttributesForElements(in: rect)
        }

        var items: [UICollectionViewLayoutAttributes] = []

        let maxSection = collectionView.numberOfSections
        let first = max(0, Int(floor(rect.origin.x / dayColumnSize.width)))
        let last = min(
            max(first, Int(ceil(rect.maxX / dayColumnSize.width))),
            maxSection
        )

        for day in first..<last {
            let layoutItems = layoutAttributesForSection(day)

            let dimmings = layoutItems[dimmingViewsKey] ?? []
            let cells = layoutItems[eventCellsKey] ?? []

            for attr in dimmings + cells where rect.intersects(attr.frame) {
                items.append(attr)
            }
        }

        return items
    }

    override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        let old = collectionView?.bounds
        return old?.width != newBounds.width
    }
}
